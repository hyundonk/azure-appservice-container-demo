resource "azurerm_user_assigned_identity" "identity" {
  resource_group_name = var.resource_group_name
  location            = var.location

  name = "${var.name}-managed-identity"
}

resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id = var.keyvault_id # data.terraform_remote_state.keyvault.outputs.keyvault_id

  tenant_id = var.tenant_id
  object_id = azurerm_user_assigned_identity.identity.principal_id

  secret_permissions = [
    "get",
  ]

  certificate_permissions = [
    "get",
  ]
}

resource "azurerm_public_ip" "gw" {
  name                = "${var.name}-pip"

  resource_group_name = var.resource_group_name
  location            = var.location

  allocation_method   = "Static"
  sku                 = "Standard"

  public_ip_prefix_id = var.public_ip_prefix_id
}

resource "azurerm_application_gateway" "gw" {
  lifecycle {
    ignore_changes = [identity]
  }

  name                = var.name

  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = var.sku
    tier     = var.tier
    capacity = var.capacity
  }

  enable_http2        = false

  identity {
    type          = "UserAssigned"
    identity_ids  = [azurerm_user_assigned_identity.identity.id]
  }

  gateway_ip_configuration {
    name      = "${var.name}-gateway-ip-configuration"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-ipconfig-public"
    public_ip_address_id = azurerm_public_ip.gw.id
  }

  frontend_ip_configuration {
    name                          = "frontend-ipconfig-private"
    private_ip_address_allocation = "static"
    private_ip_address            = var.private_ip_address
    subnet_id                     = var.subnet_id
  }

  frontend_port {
    name = "frontend-port-http"
    port = 80
  }

  frontend_port {
    name = "frontend-port-https"
    port = 443
  }

  backend_address_pool {
    name  = "backend-address-pool-default"
    fqdns = var.backend_pool_fqdns
  }

  backend_http_settings {
    name                  = "default"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    request_timeout       = "30"
    probe_name            = "probe-default"
  
    pick_host_name_from_backend_address = var.backend_pool_fqdns == null ? false : true
  }

  http_listener {
    name                            = "default-listener"
    frontend_ip_configuration_name  = "frontend-ipconfig-public"
    frontend_port_name              = "frontend-port-https"
    protocol                        = "Https"
    ssl_certificate_name            = "default"
  }

  ssl_certificate {
    name = "default"
    key_vault_secret_id = var.keyvault_secret_id
  }

  request_routing_rule {
    name                       = "ruleHttps"
    rule_type                  = "Basic"
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "backend-address-pool-default"
    backend_http_settings_name = "default"
  }

  probe {
    name                = "probe-default"
    protocol            = "http"
    path                = "/"
    #host                = # Cannot be set if pick_host_name_from_backend_http_settings is set to true

    interval            = "10"
    timeout             = "10"
    unhealthy_threshold = "2"
    pick_host_name_from_backend_http_settings = true
  }

  waf_configuration {
    enabled               = true
    firewall_mode         = "Detection"
    rule_set_version      = "3.1"
    file_upload_limit_mb  = 500
  }
}
