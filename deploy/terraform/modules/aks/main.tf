resource "azurerm_subnet" "cluster" {
  name                 = "${local.cluster_name}-subnet-eastus"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.7.2.0/23"]

}

data "azurerm_kubernetes_service_versions" "current" {
  location = azurerm_resource_group.rg.location
  include_preview = false
}


resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "${local.cluster_name}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = "${local.cluster_name}"
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  private_cluster_enabled = false
  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_B4ms"
    os_disk_size_gb = "128"
    vnet_subnet_id  = azurerm_subnet.cluster.id
    max_pods        = 60

  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "Overlay"
    pod_cidr            = "192.168.0.0/16"
    service_cidr       = "10.255.252.0/22"
    dns_service_ip     = "10.255.252.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
    secret_rotation_interval = "5m"
  }

  role_based_access_control_enabled = false

  identity {
    type = "SystemAssigned"
  }
  
  oidc_issuer_enabled = true
  workload_identity_enabled = true
  microsoft_defender {
    log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id
  }
  oms_agent {
    log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id
  }

  open_service_mesh_enabled = false
  tags = local.tags

}

resource "azurerm_container_registry" "acr" {
  name                = "acr${local.cluster_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false
}


resource "azurerm_role_assignment" "acrpull_role" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}