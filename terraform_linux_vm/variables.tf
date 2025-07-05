variable "resource_group_location" {
  type        = string
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "vm_username" {
  type        = string
  description = <<EOT
    The username for the local account that will be created on the new VM. It can be used for connecting to that VM through SSH.
    That will be also our Hadoop user (which will be executing Hadoop commands).
  EOT
  default = "azureadmin"
}

variable "ssh_path" {
  type        = string
  description = <<EOT
    Path where to save the private ssh key on our local computer for connecting to the VMs. 
    The recommended one for Windows is C:\\Users\\username\\.ssh\\id_rsa.
  EOT
}

variable "hostnames" {
    type = list(string)
    description = <<EOT
      Names of hosts we want to assign to nodes in a Hadoop cluster. The first element must be name of the master node and the next elements
      are hosts names of slave nodes.
    EOT
    default = ["master", "worker1"]
}

variable "jupyter_notebook_password" {
    type = string
    description = "Password for accessing Jupyter Notebook."
    default = "admin"
}