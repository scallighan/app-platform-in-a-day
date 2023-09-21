variable "resource_group_name" {
  type    = string
}

variable "location" {
  type    = string
}

variable "tags" {
    type    = map(string)
    default = {}   
}

variable "key_vault_uri" {
  type = string
}

variable "virtual_network_name" {
  type    = string
}

