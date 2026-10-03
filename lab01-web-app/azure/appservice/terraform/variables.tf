variable "location" {
  type    = string
  default = "centralindia"
}

variable "image_tag" {
  description = "Tag of sre-lab-app in ACR. The Makefile passes the git short SHA."
  type        = string
}

variable "app_service_sku" {
  description = "B1 is the cheapest Linux plan with Always On and health checks."
  type        = string
  default     = "B1"
}
