terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "" # Set via -backend-config in workflow
    container_name       = "tfstate"
    key                  = "vuln-mgmt.tfstate"
  }
}
