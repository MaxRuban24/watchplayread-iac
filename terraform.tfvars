subscription = "${env.ARM_SUBSCRIPTION_ID}"
resource_group = "watchplayread-app"
appname = "wpr"
location = "West Europe"
port_env_var = "80"
# db_connection_env_var = tostring("${azurerm_cosmosdb_account.dbacc.connection_strings[0]}")