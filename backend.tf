terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "soctfstateff5d98fd"
    container_name       = "tfstate"
    key                  = "vuln-mgmt.tfstate"
  }
}
