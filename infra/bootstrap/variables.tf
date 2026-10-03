variable "subscription_id" {
  description = "The NEW free-trial subscription. The Makefile refuses to run against any other."
  type        = string
}

variable "tenant_id" {
  type = string
}

variable "expected_user" {
  description = "Azure login that must be active (guards against applying to the old account)."
  type        = string
}

variable "alert_email" {
  description = "Where budget alerts go."
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget in the billing currency. 0 disables the budget."
  type        = number
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "github_owner" {
  type    = string
  default = "ucimazing"
}

variable "github_repo" {
  type    = string
  default = "azure-sre-labs"
}

variable "deploy_environments" {
  description = "GitHub environments that may deploy to Azure. Each gets a federated credential and a manual approval gate."
  type        = list(string)
  default     = ["lab01-vm"]
}
