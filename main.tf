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

  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription
}


# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.appname}acr"
  resource_group_name = var.resource_group
  location            = var.location
  sku                 = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "acrrole" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "ArcPush"
  principal_id         = "$(azurerm_container_registry.acr.identity[0])"
}

resource "azurerm_cosmosdb_account" "dbacc" {
  name                      = "${var.appname}-db"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  enable_automatic_failover = false
  enable_free_tier          = true
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "${var.appname}mongodb"
  resource_group_name = var.resource_group
  account_name        = azurerm_cosmosdb_account.dbacc.name
  throughput          = 400
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "${var.appname}-asp"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"
  sku_name            = "F1"
}

# # Create App Insights

# resource "azurerm_application_insights" "appinsights" {
#   name                = "watchplayread-app-insights"
#   location            = "${azurerm_resource_group.rg.location}"
#   resource_group_name = "${azurerm_resource_group.rg.name}"
#   application_type    = "web"
# }

# # Create the web app, pass in the App Service Plan ID
# resource "azurerm_linux_web_app" "webapp" {
#   name                  = "watchplayread-app-run"
#   location              = azurerm_resource_group.rg.location
#   resource_group_name   = azurerm_resource_group.rg.name
#   service_plan_id       = azurerm_service_plan.asp.id
#   https_only            = true
#   site_config { 
#     always_on = false
#     minimum_tls_version = "1.2" 
#     application_stack {
#       dotnet_version = "6.0"
#     }   
    
#   }
#   app_settings = {
#     "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.appinsights.instrumentation_key}"
#   }
# }