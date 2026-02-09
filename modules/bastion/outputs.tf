output "bastion_id" {
  value       = azurerm_bastion_host.bastion.id
  description = "Bastion host ID"
}

output "bastion_name" {
  value       = azurerm_bastion_host.bastion.name
  description = "Bastion host name"
}

output "bastion_public_ip" {
  value       = azurerm_public_ip.bastion_pip.ip_address
  description = "Bastion public IP"
}
