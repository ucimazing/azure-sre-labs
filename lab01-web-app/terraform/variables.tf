variable "location" {
  type    = string
  default = "southindia"
}

variable "admin_cidr" {
  description = "Your public IP as x.x.x.x/32. Only this address may SSH in. Locally: terraform.tfvars; in CI: TF_VAR_admin_cidr."
  type        = string
  sensitive   = true # the repo is public: keep your home IP out of plan output and CI logs
}
variable "vm-size" {
  type    = string
  default = "Standard_B2as_V2"
}
variable "ssh_public_key" {
  description = "SSH PUBLIC key for azureuser (contents, not a path). Not a secret. Locally: terraform.tfvars; in CI: TF_VAR_ssh_public_key."
  type        = string
}

variable "admin_object_id" {
  description = "Entra object ID of the human admin who may read Key Vault secrets. Not a secret. In CI: TF_VAR_admin_object_id."
  type        = string
}
