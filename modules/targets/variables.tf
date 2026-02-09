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

variable "subnet_targets_id" {
  type        = string
  description = "Targets subnet ID"
}

variable "admin_username" {
  type        = string
  description = "Admin username for Linux VMs"
}

variable "admin_public_key" {
  type        = string
  description = "SSH public key for Linux VMs"
}

variable "vm_size" {
  type        = string
  description = "VM size"
  default     = "Standard_D2d_v4"
}

variable "create_linux_target" {
  type        = bool
  description = "Create optional Linux target VM"
  default     = false
}

variable "create_windows_target" {
  type        = bool
  description = "Create optional Windows target VM with audit + simulation"
  default     = false
}

variable "create_juice_shop" {
  type        = bool
  description = "Create OWASP Juice Shop vulnerable web app (attack simulation)"
  default     = false
}

variable "create_dvwa" {
  type        = bool
  description = "Create DVWA vulnerable web app (attack simulation)"
  default     = false
}

variable "windows_admin_username" {
  type        = string
  description = "Windows admin username"
  default     = "winadmin"
}

variable "windows_admin_password" {
  type        = string
  description = "Windows admin password (12+ chars, complexity)"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}
