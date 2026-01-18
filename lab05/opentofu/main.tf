# Main resource definitions
# This file contains the actual infrastructure resources to create

# =============================================================================
# Azure Resources
# =============================================================================

# Azure Resource Group
# A resource group is a logical container for Azure resources
# All Azure resources must belong to a resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment  = var.environment
    project      = var.project_name
    managed-by   = "opentofu"
    workshop     = "platform-engineering"
    created-date = formatdate("YYYY-MM-DD", timestamp())
  }

  # Lifecycle settings
  lifecycle {
    # Prevent accidental deletion in production
    # Uncomment for production use:
    # prevent_destroy = var.environment == "prod"
  }
}

# =============================================================================
# GitHub Resources
# =============================================================================

# GitHub Repository
# Creates a new repository in your GitHub account
resource "github_repository" "main" {
  name        = var.github_repo_name
  description = var.github_repo_description
  visibility  = var.github_repo_visibility

  # Repository settings
  auto_init          = true    # Create with initial commit
  has_issues         = true    # Enable issues
  has_wiki           = false   # Disable wiki
  has_projects       = false   # Disable projects
  has_discussions    = false   # Disable discussions
  has_downloads      = true    # Enable downloads
  archive_on_destroy = false   # Delete (not archive) when destroyed

  # Topics for discoverability
  topics = var.github_repo_topics

  # Vulnerability alerts for public repos
  vulnerability_alerts = var.github_repo_visibility == "public"

  # Security settings
  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }
}

# =============================================================================
# Example: Cross-Provider Integration
# =============================================================================

# You could store Azure resource information in the GitHub repo
# This demonstrates how providers can work together

# Example: Create a file in the GitHub repo with Azure info
# Uncomment to use:
#
# resource "github_repository_file" "azure_info" {
#   repository          = github_repository.main.name
#   branch              = "main"
#   file                = "AZURE_RESOURCES.md"
#   content             = <<-EOT
#     # Azure Resources
#     
#     This repository is connected to the following Azure resources:
#     
#     - **Resource Group**: ${azurerm_resource_group.main.name}
#     - **Location**: ${azurerm_resource_group.main.location}
#     - **Resource Group ID**: ${azurerm_resource_group.main.id}
#     
#     Managed by OpenTofu.
#   EOT
#   commit_message      = "Add Azure resource information"
#   overwrite_on_create = true
# }
