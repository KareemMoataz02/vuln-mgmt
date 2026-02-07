output "openvas_public_ip" {
  value       = azurerm_public_ip.openvas_pip.ip_address
  description = "OpenVAS VM public IP (UI on https://IP:9392)"
}

output "openvas_private_ip" {
  value       = azurerm_network_interface.openvas_nic.private_ip_address
  description = "OpenVAS VM private IP"
}

output "linux_target_private_ip" {
  value       = try(azurerm_network_interface.linux_target_nic[0].private_ip_address, null)
  description = "Linux target private IP (if created)"
}

output "windows_target_private_ip" {
  value       = try(azurerm_network_interface.windows_target_nic[0].private_ip_address, null)
  description = "Windows target private IP (if created)"
}
