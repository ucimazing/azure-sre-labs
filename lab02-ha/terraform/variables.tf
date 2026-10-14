variable "location" {
  description = "Azure region (programmatic name)."
  type        = string
  default     = "indiasouthcentral"
}

variable "ci_object_id" {
  description = "Object ID of the CI pipeline's service principal (gh-oidc-azure-sre-labs). Gets AcrPush and Key Vault Secrets Officer."
  type        = string
}

variable "admin_object_id" {
  description = "Object ID of the human admin (you). Gets Key Vault Secrets Officer, to read secrets when debugging."
  type        = string
}
