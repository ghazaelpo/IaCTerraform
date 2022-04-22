data "azurerm_resource_group" "main" {
  name = "finalproject"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "boutiqueaks1"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "boutiqueaks1"

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

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = data.azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = data.azurerm_resource_group.main.location
    resource_group_name          = data.azurerm_resource_group.main.name
    allocation_method            = "Dynamic"

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "VAULT"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "8200"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "mynic"
    location                  = data.azurerm_resource_group.main.location
    resource_group_name       = data.azurerm_resource_group.main.name

    ip_configuration {
        name                          = "mynicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

resource "azurerm_ssh_public_key" "example" {
  name                = "myssh"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = data.azurerm_resource_group.main.location
    resource_group_name   = data.azurerm_resource_group.main.name
    size                  = "Standard_B1s"
    network_interface_ids = [
      azurerm_network_interface.myterraformnic.id,
      ]
    

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

      admin_ssh_key {
    username   = "myvault"
    public_key = file("~/.ssh/id_rsa.pub")
  }

    computer_name  = "myvm"
    admin_username = "myvault"
    admin_password = "Vault1234!"
    disable_password_authentication = false

 
}