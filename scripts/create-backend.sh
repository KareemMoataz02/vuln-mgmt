#!/bin/bash
set -e

echo "🚀 Creating Azure Storage Backend for Terraform State"
echo "======================================================="

# Configuration
RESOURCE_GROUP="tfstate-rg"
LOCATION="uaenorth"
CONTAINER_NAME="tfstate"

# Generate unique storage account name
STORAGE_ACCOUNT="soctfstate$(openssl rand -hex 4)"

echo ""
echo "📦 Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

echo ""
echo "💾 Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output table

echo ""
echo "🔑 Retrieving storage account key..."
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT" \
  --query '[0].value' -o tsv)

echo ""
echo "📁 Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$ACCOUNT_KEY" \
  --output table

echo ""
echo "✅ Backend infrastructure created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Add these to your GitHub Repository Secrets:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Secret Name: BACKEND_STORAGE_ACCOUNT"
echo "Value:       $STORAGE_ACCOUNT"
echo ""
echo "Secret Name: BACKEND_ACCESS_KEY"
echo "Value:       $ACCOUNT_KEY"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Next steps:"
echo "1. Add the secrets above to GitHub (Settings → Secrets → Actions)"
echo "2. Commit and push your changes"
echo "3. The pipeline will automatically use the remote backend"
echo ""
