# Building a VM with RDP access with Terraform

This repository provides guidance on provisioning and managing Azure resources seamlessly using HashiCorp's Terraform. Dive into each component of the provided Terraform script, which establishes an Azure virtual machine and its associated infrastructure.

## Prerequisites

Before you proceed, ensure you have:

- [Terraform](https://www.terraform.io/downloads.html) installed.
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) installed.
- Azure credentials set up and authenticated.

## Setting and Using Variables

This Terraform script makes use of variables to allow flexibility and customization. Before using the script, ensure you set the required variables.

- `location`: Specifies the Azure region for resource deployment. Default is `eastus`.
- `admin_password`: The password for the Windows VM. It should be provided during Terraform command execution and not hard-coded for security reasons.
- `tags`: A map of tags to assign to resources, allowing you to categorize and manage them more efficiently. Default is `{ environment = "development" }`.

Here are the defined variables:

```hcl
variable "location" {
  description = "Azure region for the resources. Default is eastus."
  default     = "eastus"
}

variable "admin_password" {
  description = "The admin password for the VM."
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to be added to resources. Default is { environment = "development" }."
  type        = map(string)
  default = {
    environment = "development"
  }
}
```

When running Terraform commands, you can provide variable values using one of these methods:

1. **Command-line Flags**: Pass variables directly through the command line:

   ```bash
   terraform apply -var "admin_password=YOUR_SECURE_PASSWORD"
   ```

2. **Terraform.tfvars**: Create a file named `terraform.tfvars` in the same directory as your main Terraform files, and specify the variable values:

   ```hcl
   admin_password = "YOUR_SECURE_PASSWORD"
   ```

3. **Environment Variables**: Set variables using the `TF_VAR_name` format:

   ```bash
   export TF_VAR_admin_password="YOUR_SECURE_PASSWORD"
   ```

Ensure that sensitive information, especially passwords, are not hard-coded or checked into source control.

## Terraform Configuration

```hcl
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
```

## Resource Creation

### Create Azure Resource Group

```hcl
resource "azurerm_resource_group" "main" {
  name     = "tf-proj-rg-${var.location}"
  location = var.location
  tags     = var.tags
}
```

- **Resource Type**: `azurerm_resource_group`
- **Resource Name**: `main`
- **Attributes**:
  - `name`: Name of the Azure Resource Group, influenced by the provided location variable.
  - `location`: Azure region or location for the resource group, derived from the `location` variable.
  - `tags`: Tags associated with the resource group, derived from the `tags` variable.

### Create Azure Virtual Network

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "tf-proj-vnet-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}
```

- **Resource Type**: `azurerm_virtual_network`
- **Resource Name**: `main`
- **Attributes**:
  - `name`: Name of the Azure Virtual Network.
  - `location`: Derived from the previously created resource group.
  - `resource_group_name`: Name of the associated resource group.
  - `address_space`: IP address space for the virtual network.

### Create Azure Subnet

```hcl
resource "azurerm_subnet" "main" {
  name                 = "tf-proj-subnet-${var.location}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = ["10.0.0.0/24"]
}
```

- **Resource Type**: `azurerm_subnet`
- **Resource Name**: `main`
- **Attributes**:
  - `name`: Name of the Azure Subnet.
  - `virtual_network_name`: Name of the associated virtual network.
  - `resource_group_name`: Name of the associated resource group.
  - `address_prefixes`: IP address prefix for the subnet.

### Create Azure Network Interface Card (NIC)

```hcl
resource "azurerm_network_interface" "internal" {
  name                = "tf-proj-nic-${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}
```

- **Resource Type**: `azurerm_network_interface`
- **Resource Name**: `internal`
- **Attributes**:
  - `name`: Name of the NIC.
  - `location`: Location derived from the associated resource group.
  - `resource_group_name`: Name of the associated resource group.
  - `ip_configuration`: IP configuration settings, including its name, subnet ID, and IP address allocation mode.


## Create Azure Network Security Group for RDP

To secure the VM, we have added a network security group that allows only RDP access.

```hcl
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
```

- **Resource Type**: `azurerm_network_security_group`
- **Resource Name**: `main`
- **Attributes**:
  - `name`: Name of the Network Security Group.
  - `location`: Location derived from the main resource group.
  - `security_rule`: Contains settings for allowing RDP traffic.

### Associate Network Security Group with Subnet

To ensure that the rules defined in the network security group apply to resources in our subnet, we associate the two.

```hcl
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}
```

- **Resource Type**: `azurerm_subnet_network_security_group_association`
- **Resource Name**: `main`
- **Attributes**:
  - `subnet_id`: ID of the previously defined subnet.
  - `network_security_group_id`: ID of the network security group created to allow RDP.


### Create Azure Virtual Machine

```hcl
resource "azurerm_windows_virtual_machine" "main" {
  name                     = "tf-proj-vm-${var.location}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  size                     = "Standard_B1s"
  admin_username           = "user.admin"
  admin_password           =

 var.admin_password
  network_interface_ids    = [azurerm_network_interface.internal.id]
  tags                     = var.tags

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
```

- **Resource Type**: `azurerm_windows_virtual_machine`
- **Resource Name**: `main`
- **Attributes**:
  - `name`: Name of the VM.
  - `resource_group_name`: Name of the associated resource group.
  - `location`: Location derived from the associated resource group.
  - `admin_username`: Admin username for the VM.
  - `admin_password`: Admin password derived from the `admin_password` variable.
  - `network_interface_ids`: IDs of associated network interfaces.
  - `os_disk`: OS disk configuration, including caching and storage account type.
  - `source_image_reference`: Source image reference for the VM.

## Usage

1. Initialize the Terraform workspace:

```bash
terraform init
```

2. Plan the deployment, providing necessary variables:

```bash
terraform plan -var="admin_password=YOUR_SECURE_PASSWORD"
```

3. Apply the infrastructure changes:

```bash
terraform apply -var="admin_password=YOUR_SECURE_PASSWORD"
```

4. Review and confirm the changes when prompted.

## Cleanup

To destroy the provisioned resources:

```bash
terraform destroy
```

Always review the plan output and ensure you understand the resources being destroyed.

## Note
Azure can sometimes have slight delays in allocating and associating dynamic public IPs. When using Dynamic allocation method, the IP address is not assigned until the associated resource (like a VM or Load Balancer) is started.
Running terraform apply again usually will show the output IP.

Remember to double-check that resources have been terminated to avoid costs.
