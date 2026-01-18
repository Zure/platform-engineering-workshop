# Output definitions
# These values are displayed after deployment and can be used by other configurations

# =============================================================================
# Azure Outputs
# =============================================================================

output "azure_resource_group_name" {
  description = "Name of the created Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "azure_resource_group_id" {
  description = "Full resource ID of the Azure Resource Group"
  value       = azurerm_resource_group.main.id
}

output "azure_resource_group_location" {
  description = "Azure region where the Resource Group was created"
  value       = azurerm_resource_group.main.location
}

output "azure_portal_url" {
  description = "Direct link to the Resource Group in Azure Portal"
  value       = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
}

# =============================================================================
# GitHub Outputs
# =============================================================================

output "github_repository_name" {
  description = "Name of the created GitHub repository"
  value       = github_repository.main.name
}

output "github_repository_full_name" {
  description = "Full name of the repository (owner/name)"
  value       = github_repository.main.full_name
}

output "github_repository_url" {
  description = "Web URL of the GitHub repository"
  value       = github_repository.main.html_url
}

output "github_repository_clone_url_https" {
  description = "HTTPS clone URL for the repository"
  value       = github_repository.main.http_clone_url
}

output "github_repository_clone_url_ssh" {
  description = "SSH clone URL for the repository"
  value       = github_repository.main.ssh_clone_url
}

output "github_repository_visibility" {
  description = "Visibility setting of the repository"
  value       = github_repository.main.visibility
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Summary of all deployed resources"
  value = {
    azure = {
      resource_group = azurerm_resource_group.main.name
      location       = azurerm_resource_group.main.location
      portal_url     = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
    }
    github = {
      repository = github_repository.main.name
      url        = github_repository.main.html_url
      visibility = github_repository.main.visibility
    }
    metadata = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "opentofu"
    }
  }
}
