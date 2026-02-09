variable "name" {
  type        = string
  description = "Prefix for resource names"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "subnet_security_id" {
  type        = string
  description = "Security tools subnet ID"
}

variable "admin_username" {
  type        = string
  description = "Admin username for Linux VM"
}

variable "admin_public_key" {
  type        = string
  description = "SSH public key for Linux VM"
}

variable "vm_size" {
  type        = string
  description = "VM size"
  default     = "Standard_D2d_v4"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}
