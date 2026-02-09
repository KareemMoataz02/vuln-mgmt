#!/bin/bash
# Bootstrap remote state backend: creates RG + Storage Account + Container for Terraform state
# Usage: ./scripts/bootstrap-backend.sh <storage_account_name> [location]
# Example: ./scripts/bootstrap-backend.sh mytfstatelab uaenorth

set -e
STORAGE_NAME="${1:?Usage: $0 <storage_account_name> [location]}"
LOCATION="${2:-uaenorth}"
RG="tfstate-rg"
CONTAINER="tfstate"

echo "Creating resource group $RG in $LOCATION..."
az group create -n "$RG" -l "$LOCATION"

echo "Creating storage account $STORAGE_NAME..."
az storage account create -n "$STORAGE_NAME" -g "$RG" -l "$LOCATION" --sku Standard_LRS

echo "Creating container $CONTAINER..."
az storage container create -n "$CONTAINER" --account-name "$STORAGE_NAME"

echo ""
echo "Done! Add to backend.tf:"
echo "  backend \"azurerm\" {"
echo "    resource_group_name  = \"$RG\""
echo "    storage_account_name = \"$STORAGE_NAME\""
echo "    container_name       = \"$CONTAINER\""
echo "    key                  = \"soc-openvas.tfstate\""
echo "  }"
echo ""
echo "Then run: terraform init -reconfigure"
