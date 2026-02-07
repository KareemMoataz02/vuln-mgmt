variable "location" {
  type        = string
  description = "Azure region"
  default     = "uaenorth"

}

variable "project_name" {
  type        = string
  description = "Prefix for resources"
  default     = "soc-openvas"
}

variable "admin_username" {
  type        = string
  description = "Admin username for VMs"
  default     = "azureuser"
}

variable "admin_public_key" {
  type        = string
  description = "SSH public key for Linux VMs"
}

variable "my_public_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR for restricting OpenVAS UI/SSH (example: 1.2.3.4/32)"
}

variable "create_linux_target" {
  type        = bool
  default     = true
}

variable "create_windows_target" {
  type        = bool
  default     = false
}

variable "windows_admin_username" {
  type        = string
  default     = "winadmin"
}

variable "windows_admin_password" {
  type        = string
  description = "Windows admin password (12+ chars, complexity)."
  sensitive   = true
  default     = null
}
