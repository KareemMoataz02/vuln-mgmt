# -------------------------
# Root module - wires network, bastion, scanner, targets, monitoring
# -------------------------
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

locals {
  name = "${var.project_name}-${random_string.suffix.result}"

  tags = {
    project = var.project_name
    env     = var.environment
  }
}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.tags
}

# -------------------------
# Key Vault for secrets (no passwords in tfvars/state when using random)
# -------------------------
resource "azurerm_key_vault" "kv" {
  name                       = substr(replace("${local.name}-kv", "-", ""), 0, 24)
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

resource "random_password" "windows_admin" {
  count = var.create_windows_target ? 1 : 0

  length           = 16
  special          = true
  override_special = "!@#$%&*"
}

resource "azurerm_key_vault_secret" "windows_admin_password" {
  count = var.create_windows_target ? 1 : 0

  name         = "windows-admin-password"
  value        = coalesce(var.windows_admin_password, random_password.windows_admin[0].result)
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

locals {
  windows_admin_password = var.create_windows_target ? coalesce(var.windows_admin_password, random_password.windows_admin[0].result) : null
}

# -------------------------
# Network module
# -------------------------
module "network" {
  source = "./modules/network"

  name                = local.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# -------------------------
# Bastion module
# -------------------------
module "bastion" {
  source = "./modules/bastion"

  name                = local.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_bastion_id   = module.network.subnet_bastion_id
  tags                = local.tags
}

# -------------------------
# Scanner module (OpenVAS)
# -------------------------
module "scanner" {
  source = "./modules/scanner"

  name                = local.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_security_id  = module.network.subnet_security_id
  admin_username      = var.admin_username
  admin_public_key    = var.admin_public_key
  vm_size             = var.openvas_vm_size
  tags                = local.tags
}

# -------------------------
# Targets module (Linux, Windows, Juice Shop, DVWA)
# -------------------------
module "targets" {
  source = "./modules/targets"

  name                = local.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_targets_id   = module.network.subnet_targets_id
  admin_username      = var.admin_username
  admin_public_key    = var.admin_public_key
  vm_size             = var.target_vm_size
  tags                = local.tags

  create_linux_target   = var.create_linux_target
  create_windows_target = var.create_windows_target
  create_juice_shop     = var.create_juice_shop
  create_dvwa           = var.create_dvwa

  windows_admin_username = var.windows_admin_username
  windows_admin_password = coalesce(local.windows_admin_password, "dummy-not-used")
}

# -------------------------
# Monitoring module (Log Analytics, Sentinel, Defender for Cloud, Defender-to-Sentinel connector)
# -------------------------
module "monitoring" {
  source = "./modules/monitoring"

  name                         = local.name
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  log_analytics_retention_days = var.log_analytics_retention_days
  enable_defender_for_cloud    = var.enable_defender_for_cloud
  tags                         = local.tags

  nsg_ids = var.enable_defender_for_cloud ? {
    openvas = module.network.nsg_openvas_id
    targets = module.network.nsg_targets_id
  } : {}

  openvas_vm_id           = module.scanner.openvas_id
  create_linux_target_dcr = var.create_linux_target
  linux_target_vm_id      = var.create_linux_target ? (module.targets.linux_target_id != null ? module.targets.linux_target_id : "") : ""
  create_juice_shop_dcr   = var.create_juice_shop
  juice_shop_vm_id        = var.create_juice_shop ? (module.targets.juice_shop_id != null ? module.targets.juice_shop_id : "") : ""
  create_dvwa_dcr         = var.create_dvwa
  dvwa_vm_id              = var.create_dvwa ? (module.targets.dvwa_id != null ? module.targets.dvwa_id : "") : ""

  linux_vm_ids = {
    openvas      = module.scanner.openvas_id
    linux_target = var.create_linux_target ? module.targets.linux_target_id : ""
    juice_shop   = var.create_juice_shop ? module.targets.juice_shop_id : ""
    dvwa         = var.create_dvwa ? module.targets.dvwa_id : ""
  }
}
