variable "location" {
  type    = string
  default = "southindia"
}

variable "admin_cidr" {
  description = "Your public IP as x.x.x.x/32. Only this address may SSH in. Set it in terraform.tfvars."
  type        = string
}
variable "vm-size" {
  type = string
  default = "Standard_B2as_V2"
}