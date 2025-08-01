module "resource_group" {
  source = "./modules/resource_group"
  name = var.resource_group_name
  location = var.resource_group_location
}

# Create an ACR where we will be pushing Docker image with Spark used for submitting Spark jobs to Kubernetes
# using SparkApplication resource.
module "acr" {
  source = "./modules/acr"
  acr_name                = "sparkScripts" # Name of the created ACR
  resource_group_name     = var.resource_group_name
  resource_group_location = var.resource_group_location
}

# Service Principal for authentication to the ACR.
module "service_principal" {
  source = "./modules/service_principal"
  service_principal_display_name = "spark_scripts_acr"
  scope = module.acr.id
  role = "acrpush"  # Allow for both pushing and pulling images from ACR.
}

# Prepare networks for our VMs.
module "networks" {
  source = "./modules/networks"
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location
}

# Generate ssh keys for connecting from our local computer to both VMs. The private key will be saved on our
# local computer at the path specified by the ssh_path.
module "ssh_1"{
  source = "./modules/ssh"
  resource_group_id = module.resource_group.id
  resource_group_location = module.resource_group.location
  ssh_path = var.ssh_path
}

# Storage account for saving logs from VMs.
module "storage_account" {
  source = "./modules/storage_account"
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location
}

# Prepare the first VM. It will act as a master node.
module "linux_vm_1" {
  source = "./modules/linux_vm"
  
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location

  # vm_size = "Standard_B4ms"
  vm_size = "Standard_B2ms"
  vm_name = "VM1"
  hostname = var.hostnames[0] # hostname of the Master Node
  subnet_id = module.networks.subnet_id
  nsg_id = module.networks.nsg_id

  username = var.vm_username # username of the user which will be created on the VM
  public_key = module.ssh_1.public_key # Public SSH key for connecting to that VM from our local computer.

  storage_account_uri = module.storage_account.primary_blob_endpoint
}



# Prepare the second VM. It will act as a worker node.
module "linux_vm_2" {
  source = "./modules/linux_vm"
  
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location

  # vm_size = "Standard_B4ms"
  vm_size = "Standard_B2ms"
  vm_name = "VM2"
  hostname = var.hostnames[1] # hostname of the Slave Node
  subnet_id = module.networks.subnet_id
  nsg_id = module.networks.nsg_id

  username = var.vm_username # username of the user which will be created on the VM
  public_key = module.ssh_1.public_key # Public SSH key for connecting to that VM from our local computer.

  storage_account_uri = module.storage_account.primary_blob_endpoint
}



# Execute bash scripts on the created VMs in order to configure Spark and Kubernetes. For that we are using the azurerm_virtual_machine_extension
# resource which uses the Azure VM Extension.

# Configure the VM1 by executing a bash script which will set up a passwordless SSH connection from VM1 to VM2
# and configure Spark and Kubernetes.
resource "azurerm_virtual_machine_extension" "vm1_configure" {
  name                 = "vm1_configure"
  virtual_machine_id   = module.linux_vm_1.vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  protected_settings = jsonencode({
    # Insert variables into the bash script using the templatefile function before executing them.
    script = base64encode(templatefile("bash_scripts/vm1_configure.tftpl", {
      username = var.vm_username # User which will be created on the VM.
      jupyter_notebook_password = var.jupyter_notebook_password # password for accessing Jupyter Notebook
      acr_url = module.acr.url
      acr_sp_id = module.service_principal.client_id # Service Principal Client ID for authentication to the ACR
      acr_sp_password = module.service_principal.client_password # Service Principal password for authentication to the ACR
    }))
  })
}


# Configure the VM2 by executing a bash script which will set up a passwordless SSH connection from VM1 to VM2
# and configure Spark and Kubernetes.
resource "azurerm_virtual_machine_extension" "vm2_configure" {
  name                 = "vm2_configure"
  virtual_machine_id   = module.linux_vm_2.vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  protected_settings = jsonencode({
    # Insert variables into the bash script using the templatefile function before executing them.
    script = base64encode(templatefile("bash_scripts/vm2_configure.tftpl", {
      username = var.vm_username # User which will be created on the VM.
    }))
  })
}
