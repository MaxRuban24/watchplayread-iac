# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.42.0"
    }
  }
    # Store state file in separate Azure container
    backend "azurerm" {
      resource_group_name  = "iac-secure"
      storage_account_name = "tfstorage202302"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
  }

  required_version = ">= 1.2.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "watchplayread-app"
  location = "West Europe"
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "watchplayread-app-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "F1"
}

# Create App Insights

resource "azurerm_application_insights" "appinsights" {
  name                = "watchplayread-app-insights"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  application_type    = "web"
}

# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapp" {
  name                  = "watchplayread-app-run"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.asp.id
  https_only            = true
  site_config { 
    always_on = false
    minimum_tls_version = "1.2" 
    application_stack {
      dotnet_version = "6.0"
    }   
    
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.appinsights.instrumentation_key}"
  }
}

#  Deploy code from a public GitHub repo
resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id             = azurerm_linux_web_app.webapp.id
  repo_url           = "https://mruban@dev.azure.com/mruban/azure-task-L1/_git/azure-task-L1"
  branch             = "master"
  use_manual_integration = true
  use_mercurial      = false
}