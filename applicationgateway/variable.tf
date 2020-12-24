variable "resource_group_name" {}
variable "location" {}
variable "name" {}
variable "tenant_id" {}

variable "public_ip_prefix_id" {
  default = null
}

variable "keyvault_id" {}
variable "keyvault_secret_id" {}
variable "subnet_id" {}
variable "private_ip_address" {}

variable "sku" {
  default = "WAF_v2"
}
  
variable "tier" {
  default = "WAF_v2"
}

variable "capacity" {
  default = 2
}

variable "backend_pool_fqdns" {
  default = null
}


