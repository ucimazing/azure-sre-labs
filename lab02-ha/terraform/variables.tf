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

variable "ssh_public_key" {
  description = "SSH public key for azureuser on the app servers. Emergency access only (serial console, Bastion); nobody SSHes in normally."
  type        = string
}

variable "app_image_tag" {
  description = "Which sre-lab-app image the servers run: the git commit SHA it was built from (an existing tag in ACR)."
  type        = string
}
