locals {
  linux_target_juice_cloud_init = <<-EOF
#cloud-config
package_update: true
package_upgrade: true
runcmd:
  - apt-get update && apt-get install -y ca-certificates curl gnupg
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable --now docker
  - sleep 30
  - docker run -d --name juice-shop -p 3000:3000 --restart unless-stopped bkimminich/juice-shop
EOF
}

# ---------------------------
# OPTIONAL: Linux target VM
# ---------------------------
resource "azurerm_network_interface" "linux_target_nic" {
  count               = var.create_linux_target ? 1 : 0
  name                = "${var.name}-lin-tgt-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_targets_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "linux_target" {
  count               = var.create_linux_target ? 1 : 0
  name                = "${var.name}-linux-target"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_D2d_v4"
  tags                = var.tags

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.linux_target_nic[0].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  user_data = base64encode(local.linux_target_juice_cloud_init)
}

resource "azurerm_virtual_machine_extension" "ama_linux_target" {
  count                      = var.create_linux_target ? 1 : 0
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux_target[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# ---------------------------
# OPTIONAL: Windows target VM (with audit policies + bad behavior simulation)
# ---------------------------
resource "azurerm_network_interface" "windows_target_nic" {
  count               = var.create_windows_target ? 1 : 0
  name                = "${var.name}-win-tgt-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_targets_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "windows_target" {
  count               = var.create_windows_target ? 1 : 0
  name                = "${var.name}-windows-target"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  tags                = var.tags

  admin_username = var.windows_admin_username
  admin_password = var.windows_admin_password

  network_interface_ids = [azurerm_network_interface.windows_target_nic[0].id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Enable audit policies and inject "bad behavior" script (failed logons, suspicious PowerShell)
resource "azurerm_virtual_machine_extension" "ama_windows_target" {
  count                      = var.create_windows_target ? 1 : 0
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.windows_target[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "windows_audit_and_simulation" {
  count                = var.create_windows_target ? 1 : 0
  name                 = "AuditAndSimulation"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_target[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -EncodedCommand ${base64encode(file("${path.module}/scripts/windows-simulation.ps1"))}"
  })

  depends_on = [azurerm_virtual_machine_extension.ama_windows_target]
}

# ---------------------------
# OPTIONAL: OWASP Juice Shop (deliberately vulnerable web app)
# ---------------------------
locals {
  juice_shop_cloud_init = <<-EOF
#cloud-config
package_update: true
package_upgrade: true
runcmd:
  - apt-get update && apt-get install -y ca-certificates curl gnupg
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable --now docker
  - sleep 30
  - docker run -d --name juice-shop -p 3000:3000 --restart unless-stopped bkimminich/juice-shop
EOF
}

resource "azurerm_network_interface" "juice_shop_nic" {
  count               = 0
  name                = "${var.name}-juice-shop-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { purpose = "attack-simulation" })

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_targets_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "juice_shop" {
  count               = 0
  name                = "${var.name}-juice-shop"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  tags                = merge(var.tags, { purpose = "attack-simulation" })

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.juice_shop_nic[0].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  user_data = base64encode(local.juice_shop_cloud_init)
}

resource "azurerm_virtual_machine_extension" "ama_juice_shop" {
  count                      = 0
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.juice_shop[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# ---------------------------
# OPTIONAL: DVWA (Damn Vulnerable Web Application)
# ---------------------------
locals {
  dvwa_cloud_init = <<-EOF
#cloud-config
package_update: true
package_upgrade: true
runcmd:
  - apt-get update && apt-get install -y ca-certificates curl gnupg
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable --now docker
  - sleep 30
  - docker run -d --name dvwa -p 80:80 --restart unless-stopped vulnerables/web-dvwa
EOF
}

resource "azurerm_network_interface" "dvwa_nic" {
  count               = var.create_dvwa ? 1 : 0
  name                = "${var.name}-dvwa-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { purpose = "attack-simulation" })

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_targets_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "dvwa" {
  count               = var.create_dvwa ? 1 : 0
  name                = "${var.name}-dvwa"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B1s"
  tags                = merge(var.tags, { purpose = "attack-simulation" })

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.dvwa_nic[0].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  user_data = base64encode(local.dvwa_cloud_init)
}

resource "azurerm_virtual_machine_extension" "ama_dvwa" {
  count                      = var.create_dvwa ? 1 : 0
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.dvwa[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}
