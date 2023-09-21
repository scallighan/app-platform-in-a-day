# 10.7.2.0 - 10.7.3.255
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.7.2.0/23"]

}