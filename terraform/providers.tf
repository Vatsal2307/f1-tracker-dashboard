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
    storage_account_name = "saf1trackertfstate23678" # Your tfstate storage account
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  use_oidc = true
}