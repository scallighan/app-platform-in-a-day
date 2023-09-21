---
layout: default
title: staticwebapp
nav_exclude: true
---
# 10.7.6.0 - 10.7.6.255
resource "azurerm_subnet" "staticwebapp" {
  name                 = "staticwebapp-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.7.6.0/24"]

}