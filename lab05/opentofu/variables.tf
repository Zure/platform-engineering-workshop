# Variable definitions
# This file defines all input variables with descriptions, types, and validation

# =============================================================================
# Azure Variables
# =============================================================================

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create"
  type        = string
  default     = "rg-workshop-dev"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.resource_group_name))
    error_message = "Resource group name can only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "location" {
  description = "Azure region for resources (e.g., swedencentral, westeurope, eastus)"
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Environment name for tagging (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for tagging and identification"
  type        = string
  default     = "platform-workshop"
}

# =============================================================================
# GitHub Variables
# =============================================================================

variable "github_repo_name" {
  description = "Name of the GitHub repository to create"
  type        = string
  default     = "workshop-infrastructure"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.github_repo_name))
    error_message = "Repository name can only contain alphanumeric characters and hyphens."
  }

  validation {
    condition     = length(var.github_repo_name) <= 100
    error_message = "Repository name must be 100 characters or less."
  }
}

variable "github_repo_description" {
  description = "Description for the GitHub repository"
  type        = string
  default     = "Infrastructure repository created by OpenTofu workshop"
}

variable "github_repo_visibility" {
  description = "Repository visibility: public or private"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.github_repo_visibility)
    error_message = "Repository visibility must be either 'public' or 'private'."
  }
}

variable "github_repo_topics" {
  description = "Topics/tags for the GitHub repository"
  type        = list(string)
  default     = ["opentofu", "terraform", "azure", "infrastructure", "workshop"]
}
