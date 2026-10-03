variable "location" {
  type    = string
  default = "centralindia"
}

variable "admin_cidr" {
  description = "Your public IP as x.x.x.x/32. Only this address may SSH in."
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "vm_size" {
  description = "B2s or B1s only (Bsv2/DSv5 quota is 0). B2s has room to build the image."
  type        = string
  default     = "Standard_B2s"
}
