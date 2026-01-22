# Provider configurations
# This file configures how OpenTofu authenticates with each cloud provider
# 
# NOTE: When using this module with Terranetes, provider configurations 
# are handled automatically by the Terranetes controller. The provider
# blocks below are only used for direct OpenTofu deployments.
#
# For Terranetes compatibility, these provider configurations are removed.
# Authentication is handled by:
# - Terranetes: Via Provider resources and secrets
# - Direct OpenTofu: Via environment variables or Azure CLI

# Uncomment the provider configurations below when running OpenTofu directly:

# provider "azurerm" {
#   features {
#     resource_group {
#       prevent_deletion_if_contains_resources = false
#     }
#   }
# }

# provider "github" {
#   # The token is read from the GITHUB_TOKEN environment variable
# }
