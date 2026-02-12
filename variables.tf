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

variable "environment" {
  type        = string
  description = "Environment tag (e.g., dev/lab/prod)"
  default     = "lab"
}

variable "admin_username" {
  type        = string
  description = "Admin username for Linux VMs"
  default     = "azureuser"
}

variable "admin_public_key" {
  type        = string
  description = "SSH public key for Linux VMs"
}

variable "openvas_vm_size" {
  type        = string
  description = "OpenVAS VM size"
  default     = "Standard_D2d_v4"
}

variable "target_vm_size" {
  type        = string
  description = "Target VM size (Linux/Windows)"
  default     = "Standard_D2d_v4"
}

variable "create_linux_target" {
  type        = bool
  description = "Create an optional Linux target VM"
  default     = true
}

variable "create_windows_target" {
  type        = bool
  description = "Create Windows target VM with audit policies + bad behavior simulation (attack simulation)"
  default     = false
}

variable "create_juice_shop" {
  type        = bool
  description = "Create OWASP Juice Shop vulnerable web app (attack simulation target)"
  default     = false
}

variable "create_dvwa" {
  type        = bool
  description = "Create DVWA vulnerable web app (attack simulation target)"
  default     = false
}

variable "windows_admin_username" {
  type    = string
  default = "winadmin"
}

variable "windows_admin_password" {
  type        = string
  description = "Windows admin password (12+ chars, complexity). Optional: if unset and create_windows_target=true, a random password is generated and stored in Key Vault"
  sensitive   = true
  default     = null
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics retention in days"
  default     = 30
}

variable "enable_defender_for_cloud" {
  type        = bool
  description = "Enable Defender for Cloud + Defender for Endpoint (MDE auto-deployed to VMs) + Sentinel connector for alerts"
  default     = true
}
