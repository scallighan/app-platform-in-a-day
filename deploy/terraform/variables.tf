variable "location" {
  type    = string
  default = "East US"
}

variable "gh_repo" {
  type = string
  default = "app-platform-in-a-day"
}

variable "deploy_aca" {
  type = bool
  default = false
}

variable "deploy_aci" {
  type = bool
  default = false
}

variable "deploy_aks" {
  type = bool
  default = false
}

variable "deploy_appservice" {
  type = bool
  default = false
}

variable "deploy_asa" {
  type = bool
  default = false
}

variable "deploy_functions" {
  type = bool
  default = false
}

variable "deploy_staticwebapp" {
  type = bool
  default = false
}