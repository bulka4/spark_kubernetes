output "name" {
    value = azurerm_container_registry.acr.name
}

output id {
    value = azurerm_container_registry.acr.id
}

output url {
    value = azurerm_container_registry.acr.login_server
    description = "URL to the ACR (of the following format: myregistry.azurecr.io)."
}