# AUTOSCALE: add a server when the scale set is busy, remove one when it's quiet.
# Azure Monitor watches the average CPU of all instances and changes the instance count.
resource "azurerm_monitor_autoscale_setting" "app" {
  name                = "autoscale-lab02-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.app.id
  tags                = local.tags

  profile {
    name = "cpu"

    # Never fewer than 3 (one per zone, so a zone failure still leaves 2),
    # never more than 4 (the 4-vCPU quota this trial has in Hyderabad).
    capacity {
      minimum = 3
      default = 3
      maximum = 4
    }

    # Scale OUT: average CPU above 70% for 5 minutes -> add 1 server, then wait 5 minutes.
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.app.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }

    # Scale IN: average CPU below 25% for 10 minutes -> remove 1 server, then wait 10 minutes.
    # Slower and more cautious than scaling out: removing capacity too early hurts users.
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.app.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 25
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT10M"
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT10M"
      }
    }
  }
}
