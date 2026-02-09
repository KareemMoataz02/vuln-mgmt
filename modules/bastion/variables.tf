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

variable "subnet_bastion_id" {
  type        = string
  description = "Bastion subnet ID"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}
