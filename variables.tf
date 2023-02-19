variable "subscription" {
  type        = string
}

variable "resource_group" {
  type        = string
}

variable "appname" {
  type        = string
  description = "Application name prefix"
}

variable "location" {
  type        = string
  description = "Azure location to deploy resources"
}

variable "port_env_var" {
  type        = string
  description = "Web App environment variable port value"
}

# variable "db_connection_env_var" {
#   type        = string
#   description = "Web App environment variable database connection string"
#   sensitive = true
# }
