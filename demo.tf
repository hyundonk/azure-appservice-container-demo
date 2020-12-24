data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                     = "registrymaeiltest01"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name

  sku                      = "Basic"
  admin_enabled            = true
}

resource "azurerm_app_service_plan" "example" {
  name                = "example-appserviceplan"

  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  kind      = "Linux"
  reserved  = true 

  sku {
    tier = "PremiumV2"
    size = "P1v2"
  }
}

resource "random_string" "random_postfix" {
    length  = 3
    upper   = false
    special = false
}

resource "azurerm_storage_account" "example" {
  name                      = "selecs${random_string.random_postfix.result}"
 
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name

  account_tier              = "Standard"
  account_replication_type  = "LRS"
}

resource "azurerm_storage_share" "example" {
  name                 = "myshare"
  storage_account_name = azurerm_storage_account.example.name
  quota                = 100
}

resource "azurerm_app_service" "dockerapp" {
  name                = "selecstestapp01"

  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  app_service_plan_id = azurerm_app_service_plan.example.id

  storage_account {
    name       = azurerm_storage_account.example.name
    account_name = azurerm_storage_account.example.name
    type       = "AzureFiles"
    access_key = azurerm_storage_account.example.primary_access_key
    share_name = azurerm_storage_share.example.name
    mount_path = "/mount"
  }

  # Do not attach Storage by default
  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    WEBSITES_PORT                       = 8000

    # Settings for private Container Registires  
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = var.acr_username 
    DOCKER_REGISTRY_SERVER_PASSWORD = var.acr_password
  }

  # Configure Docker Image to load on start
  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/appsvc-tutorial-custom-image:latest"
    always_on        = "true"
  }
/*
  identity {
    type = "SystemAssigned"
  }
*/

}

module "virtual_network" {
  source  = "github.com/hyundonk/terraform-azurerm-caf-virtual-network"

  prefix              = "demo"

  virtual_network_rg  = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  networking_object   = var.networking_object

  tags            = {}
}

resource "azurerm_network_security_rule" "appgateway1000" {
  name                        = "allow-gatewaymanager"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = "appgateway"
}


resource "azurerm_network_security_rule" "appgateway1001" {
  name                        = "allow-loadbalancer"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = "appgateway"
}

resource "azurerm_network_security_rule" "appgatewayhttps" {
  name                        = "allow-https"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = "appgateway"
}

resource "azurerm_key_vault" "kv" {
  lifecycle {
    ignore_changes = [network_acls]
  }

  name                        = "keyvault${random_string.random_postfix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name

  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  soft_delete_enabled         = true # required for "key_vault_secret_id" use for application gateway

  network_acls {
    default_action            = "Allow" # for demo purpose only. not advised for production
    #default_action           = "Deny"
    bypass                    = "AzureServices"
  }
}

# add this terraform to the key vault access policy to import certificate
resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id    = azurerm_key_vault.kv.id

  tenant_id       = data.azurerm_client_config.current.tenant_id
  object_id       = data.azurerm_client_config.current.object_id

  key_permissions = [
    "get",
  ]

  secret_permissions = [
    "get",
  ]

  certificate_permissions = [
    "get",
    "purge",
    "list",
    "create",
    "import",
    "delete",
    "recover",
    "backup",
    "restore",
    "listissuers",
  ]
}

resource "azurerm_key_vault_certificate" "certificate" {
  for_each    = var.certificates

  name        = each.value.name

  key_vault_id = azurerm_key_vault.kv.id

  certificate {
    contents = filebase64(each.value.filepath)
    password = each.value.password
  }

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }
  }

  depends_on                      = [azurerm_key_vault_access_policy.policy]
}

module demoappgw {
  source                    = "./applicationgateway"
 
  name                      = "demoappgw" 
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  
  subnet_id                 = module.virtual_network.subnet_ids_map["appgateway"]
  tenant_id                 = data.azurerm_client_config.current.tenant_id

  private_ip_address        = cidrhost(module.virtual_network.subnet_prefix_map["appgateway"], 4)
  backend_pool_fqdns        = [azurerm_app_service.dockerapp.default_site_hostname]
  keyvault_id               = azurerm_key_vault.kv.id       
  keyvault_secret_id        = azurerm_key_vault_certificate.certificate.0.secret_id
}

