# 10.7.8.0 - 10.7.15.255
resource "azurerm_subnet" "aca" {
  name                 = "aca-subnet-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = ["10.7.8.0/21"]

}
