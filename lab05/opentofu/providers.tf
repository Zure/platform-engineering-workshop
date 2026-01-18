# Provider configurations
# This file configures how OpenTofu authenticates with each cloud provider

# Azure Resource Manager Provider
# Authentication methods (in order of precedence):
# 1. Service Principal with client secret (ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID)
# 2. Azure CLI (az login)
# 3. Managed Identity (when running in Azure)
provider "azurerm" {
  features {
    # Resource group settings
    resource_group {
      # Don't prevent deletion of resource groups that contain resources
      # This is useful for workshop cleanup
      prevent_deletion_if_contains_resources = false
    }
  }

  # Subscription ID can be set via ARM_SUBSCRIPTION_ID environment variable
  # or explicitly here:
  # subscription_id = "your-subscription-id"
}

# GitHub Provider
# Authentication methods:
# 1. GITHUB_TOKEN environment variable (recommended)
# 2. GitHub CLI (gh auth login)
# 3. Explicit token in provider block (not recommended for security)
provider "github" {
  # The token is read from the GITHUB_TOKEN environment variable
  # You can also set it explicitly (not recommended):
  # token = var.github_token

  # If you need to create repos in an organization, specify it:
  # owner = "your-organization"
}
