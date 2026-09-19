terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-f1-tracker-tfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
    # Update this with the specific storage account name generated earlier
    storage_account_name = "saf1trackertfstate23678" 
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}