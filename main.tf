resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  name = "${var.project_name}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "security" {
  name                 = "security-tools"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]

  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "targets" {
  name                 = "targets"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]

  depends_on = [azurerm_virtual_network.vnet]
}


# NSG for OpenVAS VM (management access)
resource "azurerm_network_security_group" "openvas_nsg" {
  name                = "${local.name}-openvas-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH to OpenVAS (restrict to your IP)
  security_rule {
    name                       = "Allow-SSH-From-MyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_public_ip_cidr
    destination_address_prefix = "*"
  }

  # OpenVAS UI (GSA) default port 9392 (restrict to your IP)
  security_rule {
    name                       = "Allow-OpenVAS-UI-From-MyIP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9392"
    source_address_prefix      = var.my_public_ip_cidr
    destination_address_prefix = "*"
  }

  # Outbound allow all (simple lab)
  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "openvas_assoc" {
  subnet_id                 = azurerm_subnet.security.id
  network_security_group_id = azurerm_network_security_group.openvas_nsg.id
}

# NSG for Targets subnet: allow scanner subnet to reach common scan ports
resource "azurerm_network_security_group" "targets_nsg" {
  name                = "${local.name}-targets-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # From OpenVAS subnet to Linux SSH
  security_rule {
    name                       = "Allow-SSH-From-Scanner"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.10.1.0/24"
    destination_address_prefix = "*"
  }

  # From OpenVAS subnet to WinRM HTTP (5985) and HTTPS (5986)
  security_rule {
    name                       = "Allow-WinRM-From-Scanner"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = "10.10.1.0/24"
    destination_address_prefix = "*"
  }

  # From OpenVAS subnet to SMB (445) for Windows authenticated checks (if used)
  security_rule {
    name                       = "Allow-SMB-From-Scanner"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "10.10.1.0/24"
    destination_address_prefix = "*"
  }

  # From OpenVAS subnet to web ports (80/443)
  security_rule {
    name                       = "Allow-Web-From-Scanner"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "10.10.1.0/24"
    destination_address_prefix = "*"
  }

  # Deny everything else inbound (optional; Azure default is "allow vnet", so we keep it simple)
}

resource "azurerm_subnet_network_security_group_association" "targets_assoc" {
  subnet_id                 = azurerm_subnet.targets.id
  network_security_group_id = azurerm_network_security_group.targets_nsg.id
}

# Public IP for OpenVAS VM (simple lab). Better: use Bastion and no public IP.
resource "azurerm_public_ip" "openvas_pip" {
  name                = "${local.name}-openvas-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "openvas_nic" {
  name                = "${local.name}-openvas-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.security.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.openvas_pip.id
  }
}

locals {
  openvas_cloud_init = <<-EOF
  #cloud-config
  package_update: true
  packages:
    - docker.io
    - docker-compose-plugin

  write_files:
    - path: /opt/gvm/docker-compose.yml
      permissions: "0644"
      content: |
        services:
          gvm:
            image: greenbone/community-edition:latest
            container_name: gvm
            restart: unless-stopped
            ports:
              - "9392:9392"
            volumes:
              - gvm-data:/var/lib/gvm
              - postgres-data:/var/lib/postgresql
              - redis-data:/var/lib/redis
        volumes:
          gvm-data:
          postgres-data:
          redis-data:

  runcmd:
    - [ bash, -lc, "systemctl enable --now docker" ]
    - [ bash, -lc, "usermod -aG docker azureuser || true" ]
    - [ bash, -lc, "mkdir -p /opt/gvm" ]
    - [ bash, -lc, "cd /opt/gvm && docker compose up -d" ]
    - [ bash, -lc, "docker ps || true" ]
  EOF
}

resource "azurerm_linux_virtual_machine" "openvas" {
  name                = "${local.name}-openvas"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size = "Standard_D2d_v4"

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.openvas_nic.id]

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

  custom_data = base64encode(local.openvas_cloud_init)
}

# -------------------------
# OPTIONAL: Linux target VM
# -------------------------
resource "azurerm_network_interface" "linux_target_nic" {
  count               = var.create_linux_target ? 1 : 0
  name                = "${local.name}-lin-tgt-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.targets.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "linux_target" {
  count               = var.create_linux_target ? 1 : 0
  name                = "${local.name}-linux-target"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2d_v4"

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
}

# ---------------------------
# OPTIONAL: Windows target VM
# ---------------------------
resource "azurerm_network_interface" "windows_target_nic" {
  count               = var.create_windows_target ? 1 : 0
  name                = "${local.name}-win-tgt-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.targets.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "windows_target" {
  count               = var.create_windows_target ? 1 : 0
  name                = "${local.name}-windows-target"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2d_v4"

  admin_username = var.windows_admin_username
  admin_password = var.windows_admin_password

  network_interface_ids = [azurerm_network_interface.windows_target_nic[0].id]

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
