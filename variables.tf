variable "subscription" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "appname" {
  type        = string
  description = "Application name prefix"
}

variable "location" {
  type        = string
  description = "Azure location to deploy resources"
}

