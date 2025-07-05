output "public_ip_address_vm_1" {
  value = module.linux_vm_1.public_ip_address
}

output "public_ip_address_vm_2" {
  value = module.linux_vm_2.public_ip_address
}

output acr_url {
  value = module.acr.url
  description = "URL to the ACR (of the following format: myregistry.azurecr.io)"
}

output acr_sp_id {
  value = module.service_principal.client_id
  description = "Service Principal app ID used for authentication to the ACR."
  sensitive = true
}

output acr_sp_password {
  value = module.service_principal.client_password
  sensitive = true
  description = "Service Principal password used for authentication to the ACR."
  sensitive = true
}