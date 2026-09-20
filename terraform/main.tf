# Generate a random suffix for globally unique resource names
resource "random_integer" "suffix" {
  min = 1000
  max = 9999
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-f1-tracker-app"
  location = var.location
}

# 2. Azure Static Web App (Free Tier)
resource "azurerm_static_web_app" "swa" {
  name                = "swa-f1-tracker-${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location # Note: SWA has specific region availabilities; eastus2 is standard
  sku_tier            = "Free"
  sku_size            = "Free"
}


# 4. Function App Infrastructure (Consumption Plan)
resource "azurerm_storage_account" "func_sa" {
  name                     = "saf1func${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-f1-tracker"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "Y1" # Y1 is the Consumption (Free/Pay-as-you-go) tier
}

resource "azurerm_windows_function_app" "func" {
  name                       = "func-f1-tracker-${random_integer.suffix.result}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.func_sa.name
  storage_account_access_key = azurerm_storage_account.func_sa.primary_access_key

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  # Enable System-Assigned Managed Identity for passwordless SQL access
  identity {
    type = "SystemAssigned"
  }
}