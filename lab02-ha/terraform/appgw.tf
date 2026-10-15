# Application Gateway v2: the ONE public entry point. Spreads HTTP traffic across the private
# scale-set instances and only sends traffic to instances whose /readyz answers.

# The gateway's parts reference each other BY NAME. Define every name once, so a typo can't break it.
locals {
  agw_name        = "agw-lab02"
  agw_gateway_ip  = "gateway-ipcfg"
  agw_frontend_ip = "public"
  agw_port        = "http"
  agw_listener    = "http-listener"
  agw_pool        = "app-pool"
  agw_settings    = "app-8000"
  agw_probe       = "readyz"
  agw_rule        = "http-to-app"
}

# The front door's address. Zone-redundant: the SAME IP is served from all three zones.
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-lab02"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_application_gateway" "appgw" {
  name                = local.agw_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  zones               = ["1", "2", "3"] # its instances are spread across the zones
  tags                = local.tags

  # The production SKU. No fixed capacity: autoscale decides how many instances run.
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  # At least 2 instances (so they can sit in different zones), at most 3 under load.
  autoscale_configuration {
    min_capacity = 2
    max_capacity = 3
  }

  # WHERE the gateway's own instances live: its dedicated subnet.
  gateway_ip_configuration {
    name      = local.agw_gateway_ip
    subnet_id = azurerm_subnet.appgw.id
  }

  # WHAT users connect to: the public IP, on port 80.
  frontend_ip_configuration {
    name                 = local.agw_frontend_ip
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = local.agw_port
    port = 80
  }

  # "Listen for HTTP on that IP and port."
  http_listener {
    name                           = local.agw_listener
    frontend_ip_configuration_name = local.agw_frontend_ip
    frontend_port_name             = local.agw_port
    protocol                       = "Http"
  }

  # WHERE to send requests. Empty on purpose: scale-set instances register themselves (vmss.tf).
  backend_address_pool {
    name = local.agw_pool
  }

  # HOW to decide a server is healthy: GET /readyz every 10 s, out after 3 failures in a row.
  # Readiness, not liveness: an instance whose database is unreachable gets no traffic.
  probe {
    name                                      = local.agw_probe
    protocol                                  = "Http"
    path                                      = "/readyz"
    interval                                  = 10
    timeout                                   = 5
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  # HOW to talk to the servers: plain HTTP to port 8000 inside the VNet, checked by the probe.
  backend_http_settings {
    name                                = local.agw_settings
    port                                = 8000
    protocol                            = "Http"
    cookie_based_affinity               = "Disabled" # no sticky sessions: any server answers any request
    request_timeout                     = 20
    probe_name                          = local.agw_probe
    pick_host_name_from_backend_address = true
  }

  # Ties it together: requests on the listener go to the pool, using those settings.
  request_routing_rule {
    name                       = local.agw_rule
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.agw_listener
    backend_address_pool_name  = local.agw_pool
    backend_http_settings_name = local.agw_settings
  }
}

output "appgw_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}
