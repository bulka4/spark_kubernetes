variable service_principal_display_name {
    type = string
}

variable scope {
    type = string
    description = "Scope of the service principal. That is ID of a resource which will be a scope."
}

variable role {
    type = string
    description = "Role which will be assigned to the service principal."
}