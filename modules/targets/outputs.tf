output "linux_target_id" {
  value       = try(azurerm_linux_virtual_machine.linux_target[0].id, null)
  description = "Linux target VM ID"
}

output "linux_target_private_ip" {
  value       = try(azurerm_network_interface.linux_target_nic[0].private_ip_address, null)
  description = "Linux target private IP"
}

output "windows_target_id" {
  value       = try(azurerm_windows_virtual_machine.windows_target[0].id, null)
  description = "Windows target VM ID"
}

output "windows_target_private_ip" {
  value       = try(azurerm_network_interface.windows_target_nic[0].private_ip_address, null)
  description = "Windows target private IP"
}

output "dvwa_id" {
  value       = try(azurerm_linux_virtual_machine.dvwa[0].id, null)
  description = "DVWA VM ID"
}

output "dvwa_private_ip" {
  value       = try(azurerm_network_interface.dvwa_nic[0].private_ip_address, null)
  description = "DVWA private IP"
}
