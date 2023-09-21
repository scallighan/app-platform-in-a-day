---
layout: default
title: functions
nav_exclude: true
---
# 10.7.5.0 - 10.7.5.255
resource "azurerm_subnet" "functions" {
  name                 = "functions-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.7.5.0/24"]

}