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
  location            = "eastus2" # Note: SWA has specific region availabilities; eastus2 is standard
  sku_tier            = "Free"
  sku_size            = "Free"
}

# 3. SQL Server & Database (Serverless with Auto-Pause)
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-f1-tracker-${random_integer.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
}

# Allow Azure Services (like our Function App) to reach the SQL Server
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "db" {
  name                        = "sqldb-f1-tracker"
  server_id                   = azurerm_mssql_server.sql.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  
  # Serverless Gen5 configuration with auto-pause to prevent billing
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60 
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