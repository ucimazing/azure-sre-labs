variable "location" {
  type    = string
  default = "India South Central"
}
variable "ci_object_id" {
  description = "Object ID of the CI pipeline's service principal (gh-oidc-azure-sre-labs). Gets AcrPush."
  type        = string
}
