output "acr_fqdn" {
  value = azurerm_container_registry.acr.login_server
}

output "appservice_hostname" {
  value = azurerm_app_service.dockerapp.default_site_hostname
}

output "appgw_ip_address" {
  value = module.demoappgw.appgateway_ip_address
}
