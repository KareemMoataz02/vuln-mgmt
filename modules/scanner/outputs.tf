output "openvas_id" {
  value       = azurerm_linux_virtual_machine.openvas.id
  description = "OpenVAS VM resource ID"
}

output "openvas_private_ip" {
  value       = azurerm_network_interface.openvas_nic.private_ip_address
  description = "OpenVAS VM private IP"
}
