# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
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
  use_msi = true
}

# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.appname}acr1"
  resource_group_name = var.resource_group
  location            = var.location
  sku                 = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

# Create Mongodb via Azure Cosmos DB account
resource "azurerm_cosmosdb_account" "dbacc" {
  name                      = "${var.appname}-db"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  offer_type                = "Standard"
  kind                      = "MongoDB"
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
  sku_name            = "B1"
}

# Create Web App with Docker Compose support
# Terraform gives warning about this resource but newer resource version does not support Docker Compose :(
# Reference could be found here: https://github.com/hashicorp/terraform-provider-azurerm/issues/16290  
resource "azurerm_app_service" "webapp" {
  name                = "${var.appname}-app"
  location            = var.location
  resource_group_name = var.resource_group
  app_service_plan_id = azurerm_service_plan.asp.id

  site_config {
    always_on                            = false
    linux_fx_version                     = "COMPOSE|${filebase64("docker-compose.yml")}"
    acr_use_managed_identity_credentials = true
  }

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL" = azurerm_container_registry.acr.login_server
    "PORT"                       = var.port_env_var
    "MONGO_URL"                  = tostring("${azurerm_cosmosdb_account.dbacc.connection_strings[0]}")
  }

  identity {
    type = "SystemAssigned"
  }
}

# Apply System Managed Identity configured in webapp block 
resource "azurerm_role_assignment" "acrrole" {
  scope                = var.subscription
  role_definition_name = "AcrPush"
  principal_id         = azurerm_app_service.webapp.identity[0].principal_id
}

# resource "azurerm_linux_web_app" "webapp" {
#   name                  = "${var.appname}-app"
#   location              = var.location
#   resource_group_name   = var.resource_group
#   service_plan_id       = azurerm_service_plan.asp.id
#   https_only            = true
#   site_config { 
#     always_on = false
#     minimum_tls_version = "1.2"
#     container_registry_managed_identity_client_id = true
#     linux_fx_version = "COMPOSE|${filebase64("docker-compose-prod.yml")}"
#     application_stack {
#       docker_image = "COMPOSE|${filebase64("docker-compose-prod.yml")}"
#       docker_image_tag = "latest"
#     }   

#   }
#   app_settings = {
#     "DOCKER_REGISTRY_SERVER_URL" = azurerm_container_registry.acr.login_server
#     "PORT" = var.port_env_var
#     "MONGO_URL" = tostring("${azurerm_cosmosdb_account.dbacc.connection_strings[0]}")
#   }
# }