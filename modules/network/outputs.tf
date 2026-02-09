output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "Virtual network ID"
}

output "subnet_bastion_id" {
  value       = azurerm_subnet.bastion.id
  description = "Bastion subnet ID"
}

output "subnet_bastion_address_prefixes" {
  value       = azurerm_subnet.bastion.address_prefixes
  description = "Bastion subnet address prefixes"
}

output "subnet_security_id" {
  value       = azurerm_subnet.security.id
  description = "Security tools subnet ID"
}

output "subnet_security_address_prefixes" {
  value       = azurerm_subnet.security.address_prefixes
  description = "Security subnet address prefixes"
}

output "subnet_targets_id" {
  value       = azurerm_subnet.targets.id
  description = "Targets subnet ID"
}

output "nsg_openvas_id" {
  value       = azurerm_network_security_group.openvas_nsg.id
  description = "OpenVAS NSG ID"
}

output "nsg_targets_id" {
  value       = azurerm_network_security_group.targets_nsg.id
  description = "Targets NSG ID"
}
