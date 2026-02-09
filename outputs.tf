output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource group name"
}

output "bastion_name" {
  value       = module.bastion.bastion_name
  description = "Bastion host name"
}

output "bastion_public_ip" {
  value       = module.bastion.bastion_public_ip
  description = "Bastion Public IP (used by Azure Bastion service)"
}

output "openvas_private_ip" {
  value       = module.scanner.openvas_private_ip
  description = "OpenVAS VM private IP"
}

output "openvas_vm_id" {
  value       = module.scanner.openvas_id
  description = "OpenVAS VM resource ID (useful for Bastion CLI commands)"
}

output "linux_target_private_ip" {
  value       = module.targets.linux_target_private_ip
  description = "Linux target private IP (if created)"
}

output "windows_target_private_ip" {
  value       = module.targets.windows_target_private_ip
  description = "Windows target private IP (if created)"
}

output "juice_shop_private_ip" {
  value       = module.targets.juice_shop_private_ip
  description = "OWASP Juice Shop private IP (if created)"
}

output "dvwa_private_ip" {
  value       = module.targets.dvwa_private_ip
  description = "DVWA private IP (if created)"
}

output "log_analytics_workspace_id" {
  value       = module.monitoring.log_analytics_workspace_id
  description = "Log Analytics Workspace resource ID"
}

output "log_analytics_workspace_name" {
  value       = module.monitoring.log_analytics_workspace_name
  description = "Log Analytics Workspace name"
}

output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
  description = "Key Vault ID (secrets stored here)"
}

output "key_vault_name" {
  value       = azurerm_key_vault.kv.name
  description = "Key Vault name"
}
