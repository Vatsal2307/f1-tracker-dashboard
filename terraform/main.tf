# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-f1-tracker-app"
  location = var.location
}

# 2. Azure Static Web App (Free Tier)
resource "azurerm_static_web_app" "swa" {
  name                = "swa-f1-tracker"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_tier            = "Free"
  sku_size            = "Free"
}