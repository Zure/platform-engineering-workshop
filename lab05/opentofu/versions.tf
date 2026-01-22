# OpenTofu/Terraform version requirements
# This file specifies which versions of OpenTofu and providers are compatible

terraform {
  # Require OpenTofu 1.0 or higher
  required_version = ">= 1.0"

  required_providers {
    # Azure Resource Manager provider
    # Documentation: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # GitHub provider
    # Documentation: https://registry.terraform.io/providers/integrations/github/latest/docs
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Note: No backend block is defined here
  # For this workshop, we use local state
  # In production, you would configure a remote backend like:
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "tfstateXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "workshop.tfstate"
  # }
}
