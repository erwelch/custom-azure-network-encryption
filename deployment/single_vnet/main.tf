provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

provider "azurerm" {
  alias           = "key_vault_subscription"
  subscription_id = "${var.key_vault_subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group_name}vnet"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  address_prefix       = "10.0.0.0/24"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
}

resource "azurerm_public_ip" "pip" {
  name                         = "${var.vmss_prefix}-pip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.vmss_prefix}"
}

resource "azurerm_lb" "lb" {
  name                = "LoadBalancer"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  depends_on          = ["azurerm_public_ip.pip"]

  frontend_ip_configuration {
    name                 = "LBFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.pip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backlb" {
  name                = "BackEndAddressPool"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
}

resource "azurerm_lb_nat_pool" "np" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "NATPool"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "LBFrontEnd"
}

resource "azurerm_storage_account" "store" {
  name                     = "${var.resource_group_name}store"
  location                 = "${azurerm_resource_group.rg.location}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"
}

resource "azurerm_storage_container" "vhds" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.store.name}"
  container_access_type = "blob"
}

resource "azurerm_user_assigned_identity" "vmssidentity" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  name                = "vmssidentity"
}

resource "azurerm_key_vault_access_policy" "readpolicy" {
  vault_name          = "${var.keyvault_name}"
  resource_group_name = "${var.keyvault_resource_group_name}"

  key_permissions = []

  secret_permissions = [
    "get",
  ]

  certificate_permissions = [
    "get",
  ]

  tenant_id = "${var.tenant_id}"
  object_id = "${azurerm_user_assigned_identity.vmssidentity.principal_id}"
}

resource "azurerm_virtual_machine_scale_set" "scaleset" {
  name                = "vmscaleset"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  upgrade_policy_mode = "Manual"
  overprovision       = true
  depends_on          = ["azurerm_lb.lb", "azurerm_virtual_network.vnet", "azurerm_key_vault_access_policy.readpolicy"]

  sku {
    name     = "${var.vm_sku}"
    tier     = "Standard"
    capacity = "${var.instance_count}"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = ["${azurerm_user_assigned_identity.vmssidentity.id}"]
  }

  extension {
    name                 = "MSILinuxExtension"
    publisher            = "Microsoft.ManagedIdentity"
    type                 = "ManagedIdentityExtensionForLinux"
    type_handler_version = "1.0"
    settings             = "{\"port\": 50342}"
  }

  os_profile {
    computer_name_prefix = "${var.vmss_prefix}-"
    admin_username       = "${var.admin_username}"
    admin_password       = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "${var.vmss_prefix}-nic"
    primary = true

    ip_configuration {
      primary                                = true
      name                                   = "${var.vmss_prefix}-ipconfig"
      subnet_id                              = "${azurerm_subnet.subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.backlb.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.np.*.id, count.index)}"]
    }
  }

  storage_profile_os_disk {
    name           = "${var.vmss_prefix}"
    caching        = "ReadWrite"
    create_option  = "FromImage"
    vhd_containers = ["${azurerm_storage_account.store.primary_blob_endpoint}${azurerm_storage_container.vhds.name}"]
  }

  storage_profile_image_reference {
    publisher = "${var.image_publisher}"
    offer     = "${var.image_offer}"
    sku       = "${var.sku}"
    version   = "latest"
  }

  extension {
    name                 = "customScript"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
        {
          "commandToExecute": "${var.command}",
          "fileUris": ${var.files}
        }
      SETTINGS
  }
}
