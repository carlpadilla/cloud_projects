terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.75"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group

resource "azurerm_resource_group" "main" {
  name     = "tf-proj-rg-${var.location}"
  location = var.location
  tags     = var.tags
}

# Create a Virtual Network

resource "azurerm_virtual_network" "main" {
  name                = "tf-proj-vnet-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Create Azure Subnet

resource "azurerm_subnet" "main" {
  name                 = "tf-proj-subnet-${var.location}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Create Azure NIC

resource "azurerm_network_interface" "internal" {
  name                = "tf-proj-nic-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

# Create Azure NSG


resource "azurerm_network_security_group" "main" {
  name                = "tf-proj-nsg-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnet

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Create Azure Windows VM

resource "azurerm_windows_virtual_machine" "main" {
  name                  = "tf-vm-${var.location}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B1s"
  admin_username        = "user.admin"
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.internal.id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-DataCenter"
    version   = "latest"
  }
}

# Creates a Public IP 
resource "azurerm_public_ip" "example" {
  name                = "example-publicip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  #   allocation_method   = "Static" <- for ouput change to static, keep in mind a cost is associated.
}

# Output the Public IP for RDP
output "vm_rdp_address" {
  value       = azurerm_public_ip.example.ip_address
  description = "The public IP address for RDP access to the VM."
}

