# Cloud-init for Ubuntu 22.04: Greenbone/OpenVAS
locals {
  openvas_cloud_init = <<-EOF
#cloud-config
package_update: true
package_upgrade: true

runcmd:
  - [ bash, -lc, "set -euxo pipefail; exec > >(tee -a /var/log/openvas-bootstrap.log) 2>&1" ]
  - [ bash, -lc, "apt-get update" ]
  - [ bash, -lc, "apt-get install -y ca-certificates curl gnupg lsb-release" ]
  - [ bash, -lc, "install -m 0755 -d /etc/apt/keyrings" ]
  - [ bash, -lc, "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg" ]
  - [ bash, -lc, "chmod a+r /etc/apt/keyrings/docker.gpg" ]
  - [ bash, -lc, "CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME); ARCH=$(dpkg --print-architecture); echo \"deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable\" > /etc/apt/sources.list.d/docker.list" ]
  - [ bash, -lc, "apt-get update" ]
  - [ bash, -lc, "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" ]
  - [ bash, -lc, "systemctl enable --now docker" ]
  - [ bash, -lc, "for i in {1..90}; do docker info >/dev/null 2>&1 && break; echo waiting-for-docker; sleep 2; done" ]
  - [ bash, -lc, "mkdir -p /opt/gvm && cd /opt/gvm" ]
  - [ bash, -lc, "cd /opt/gvm && curl -fL -o docker-compose.yml https://greenbone.github.io/docs/latest/_static/docker-compose.yml" ]
  - [ bash, -lc, "cd /opt/gvm && sed -i 's/127\\.0\\.0\\.1:9392:80/0.0.0.0:9392:80/' docker-compose.yml || true" ]
  - [ bash, -lc, "cd /opt/gvm && COMPOSE_PROFILES=full docker compose pull" ]
  - [ bash, -lc, "cd /opt/gvm && for i in {1..12}; do COMPOSE_PROFILES=full docker compose up -d || true; sleep 15; docker compose ps --services --filter status=running | grep -qx gvmd && docker compose ps --services --filter status=running | grep -qx gsa && echo 'gvmd+gsa running' && break; echo \"waiting for gvmd/gsa (attempt $i)\"; docker compose ps || true; done" ]
  - [ bash, -lc, "cd /opt/gvm && docker compose ps || true" ]
  - [ bash, -lc, "ss -lntp | grep 9392 || true" ]
  
  # -------------------------
  # OWASP ZAP (runs alongside OpenVAS)
  # -------------------------
  - [ bash, -lc, "mkdir -p /opt/zap-data" ]
  - [ bash, -lc, "chmod 777 /opt/zap-data" ]
  - [ bash, -lc, "docker pull ghcr.io/zaproxy/zaproxy:stable" ]
  - [ bash, -lc, "docker rm -f zap-scanner > /dev/null 2>&1 || true" ]
  - [ bash, -lc, "docker run -d --name zap-scanner --restart unless-stopped -u zap -p 8080:8080 -v /opt/zap-data:/zap/wrk:rw ghcr.io/zaproxy/zaproxy:stable zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true -config api.key=zapkey123" ]
  - [ bash, -lc, "for i in {1..30}; do curl -s http://localhost:8080/JSON/core/view/version/ > /dev/null 2>&1 && echo 'ZAP is ready' && break; echo 'waiting for ZAP...'; sleep 2; done" ]
  - [ bash, -lc, "docker ps | grep zap-scanner || true" ]
  - [ bash, -lc, "echo 'Running ZAP baseline scan against Juice Shop...'" ]
  - [ bash, -lc, "docker exec zap-scanner zap-baseline.py -t http://10.10.2.4:3000 -r baseline-report.html -w baseline-report.md || true" ]
  - [ bash, -lc, "echo 'ZAP baseline scan complete. Reports saved in /opt/zap-data/'" ]
EOF
}

resource "azurerm_network_interface" "openvas_nic" {
  name                = "${var.name}-openvas-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_security_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "openvas" {
  name                = "${var.name}-openvas"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  tags                = var.tags

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.openvas_nic.id]

  identity {
    type = "SystemAssigned"
  }

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

  user_data = base64encode(local.openvas_cloud_init)
}

resource "azurerm_virtual_machine_extension" "ama_openvas" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.openvas.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}
