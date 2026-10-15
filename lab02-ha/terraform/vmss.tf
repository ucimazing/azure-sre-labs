# The app servers: a VM Scale Set in FLEXIBLE orchestration, one instance per availability zone.
# No public IPs. Each instance configures itself on first boot (cloud-init.yaml.tftpl) using only
# its managed identity: pulls the image from ACR, reads the DB password from Key Vault, starts the app.
resource "azurerm_orchestrated_virtual_machine_scale_set" "app" {
  name                = "vmss-lab02-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name  = "Standard_B1ms" # 1 vCPU / 2 GB. 3 instances = 3 of the 4 vCPUs this trial allows here
  instances = 3
  zones     = ["1", "2", "3"] # spread the instances across three datacenters

  # Required with zones: the zones already keep instances apart, so 1 fault domain per zone.
  platform_fault_domain_count = 1

  # The "badge" from H4. Every instance, including future ones from autoscale or repair, wears it.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # Serial console + boot screenshots in the portal: your emergency view if a boot goes wrong.
  boot_diagnostics {}

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "ipcfg"
      primary   = true
      subnet_id = azurerm_subnet.app.id # the private subnet: NSG = only App Gateway may reach :8000
      # No public_ip_address block on purpose: these servers are not reachable from the internet.

      # Every instance (including future autoscale/repair ones) joins the App Gateway's pool.
      # backend_address_pool is a SET, so pick our pool by name and take its id.
      application_gateway_backend_address_pool_ids = [
        for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.id if pool.name == local.agw_pool
      ]
    }
  }

  os_profile {
    # The first-boot script, filled in by Terraform, then base64-encoded (Azure's required packaging).
    custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      identity_client_id = azurerm_user_assigned_identity.app.client_id
      tenant_id          = data.azurerm_client_config.current.tenant_id
      acr_login_server   = azurerm_container_registry.lab02-acr.login_server
      image_tag          = var.app_image_tag
      key_vault_name     = azurerm_key_vault.kv.name
      postgres_fqdn      = azurerm_postgresql_flexible_server.db.fqdn
    }))

    linux_configuration {
      computer_name_prefix            = "app" # instances are named app000000, app000001, ...
      admin_username                  = "azureuser"
      disable_password_authentication = true # key only: no password to guess

      admin_ssh_key {
        username   = "azureuser"
        public_key = var.ssh_public_key
      }
    }
  }

  # ---- H7: the scale set looks after itself --------------------------------------------------

  # HEALTH: every instance runs Azure's Application Health extension, which checks /healthz
  # (LIVENESS: "is the app process alive?"). Auto-repair and rolling upgrades both rely on it.
  # Version 1.0 = "Binary Health States": HTTP 200 means Healthy. (Version 2.0 = "Rich Health
  # States" requires the body {"ApplicationHealthState": "Healthy"}; without it every instance is
  # "Unknown", which auto-repair treats as Unhealthy -> it replaced healthy servers in a loop.)
  # Deliberately NOT /readyz: if the database went down, every instance would fail readiness and
  # auto-repair would replace ALL of them, over and over (Lab 1's "restart storm").
  # App Gateway uses /readyz (send traffic?); this extension uses /healthz (replace the machine?).
  extension {
    name                               = "app-health"
    publisher                          = "Microsoft.ManagedServices"
    type                               = "ApplicationHealthLinux"
    type_handler_version               = "1.0"
    auto_upgrade_minor_version_enabled = true
    settings = jsonencode({
      protocol    = "http"
      port        = 8000
      requestPath = "/healthz"
    })
  }

  # REPAIR: an instance whose /healthz keeps failing is replaced with a fresh one.
  # grace_period: don't judge a new instance for 10 minutes (it needs ~5 to boot and run cloud-init).
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  # UPGRADES: blueprint changes (extensions, image, size) roll out ONE instance at a time.
  # 34% of 3 instances = 1 per batch; stop if more than 1 instance is unhealthy; wait 2 min between.
  # Can only be chosen when the scale set is CREATED, so changing it rebuilds the scale set once.
  upgrade_mode = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent              = 34
    max_unhealthy_instance_percent          = 34
    max_unhealthy_upgraded_instance_percent = 34
    pause_time_between_batches              = "PT2M"
    prioritize_unhealthy_instances_enabled  = true # fix broken instances first
  }

  tags = local.tags

  # The instance's first boot needs these to exist and be readable. Terraform sees most references,
  # but NOT that the identity's ROLES (and the secret) must exist before the VM boots.
  depends_on = [
    azurerm_role_assignment.app_kv,
    azurerm_role_assignment.app_acr,
    azurerm_key_vault_secret.postgres,
    azurerm_postgresql_flexible_server_database.app,
    azurerm_subnet_nat_gateway_association.natsubass,
  ]
}
