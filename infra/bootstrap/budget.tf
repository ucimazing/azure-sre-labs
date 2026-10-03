# Email alerts as spend grows. A budget only alerts: it never stops resources.
# (The free trial's spending limit is what actually stops you at $0 credit.)
resource "azurerm_consumption_budget_subscription" "labs" {
  count           = var.budget_amount > 0 ? 1 : 0
  name            = "budget-labs"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", plantimestamp())
  }

  dynamic "notification" {
    for_each = {
      actual50    = { threshold = 50, type = "Actual" }
      actual80    = { threshold = 80, type = "Actual" }
      actual100   = { threshold = 100, type = "Actual" }
      forecast100 = { threshold = 100, type = "Forecasted" }
    }
    content {
      enabled        = true
      operator       = "GreaterThan"
      threshold      = notification.value.threshold
      threshold_type = notification.value.type
      contact_emails = [var.alert_email]
    }
  }

  lifecycle {
    ignore_changes = [time_period] # start date is fixed at creation
  }
}
