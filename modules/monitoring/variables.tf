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

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics retention in days"
  default     = 30
}

variable "enable_defender_for_cloud" {
  type        = bool
  description = "Enable Defender for Cloud + Defender for Endpoint (MDE auto-deployed to VMs)"
  default     = false
}

variable "nsg_ids" {
  type        = map(string)
  description = "Map of static keys to NSG IDs for diagnostic settings (keys must be known at plan time)"
  default     = {}
}

variable "openvas_vm_id" {
  type        = string
  description = "OpenVAS VM ID for DCR association"
}

variable "create_linux_target_dcr" {
  type        = bool
  description = "Create DCR association for Linux target"
  default     = false
}

variable "linux_target_vm_id" {
  type        = string
  description = "Linux target VM ID (used when create_linux_target_dcr is true)"
  default     = ""
}

variable "create_juice_shop_dcr" {
  type        = bool
  description = "Create DCR association for Juice Shop"
  default     = false
}

variable "juice_shop_vm_id" {
  type        = string
  description = "Juice Shop VM ID (used when create_juice_shop_dcr is true)"
  default     = ""
}

variable "create_dvwa_dcr" {
  type        = bool
  description = "Create DCR association for DVWA"
  default     = false
}

variable "dvwa_vm_id" {
  type        = string
  description = "DVWA VM ID (used when create_dvwa_dcr is true)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}

variable "linux_vm_ids" {
  description = "Map of Linux VM resource IDs to associate the DCR (Azure Monitor Agent) with."
  type        = map(string)
  default     = {}
  nullable    = false
}