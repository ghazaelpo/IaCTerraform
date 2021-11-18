data "azurerm_resource_group" "main" {
  name = "mario-robles"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "boutiqueaks"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "boutiqueaks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw

  sensitive = true
}


resource "azurerm_container_registry" "acr" {
  name                = "boutiqueaksacr"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
}