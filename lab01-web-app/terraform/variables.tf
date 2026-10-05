variable "location" {
  type    = string
  default = "southindia"
}

variable "admin_cidr" {
  description = "Your public IP as x.x.x.x/32. Only this address may SSH in. Set it in terraform.tfvars."
  type        = string
}
variable "vm-size" {
  type    = string
  default = "Standard_B2as_V2"
}
variable "ssh_public_key" {
  description = "SSH PUBLIC key for azureuser (contents, not a path). Not a secret. Locally: terraform.tfvars; in CI: TF_VAR_ssh_public_key."
  type        = string
}
