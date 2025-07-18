# Introduction
This repository contains code for:
- Creating two Azure Linux VMs (VM1 and VM2) using Terraform
- Setting up a Spark (Local Mode) and running a Jupyter Notebook on the VM1
- Set up Kubernetes cluster on both VMs

We will be able to access a Jupyter Notebook through a browser and create there notebooks for developing and running Spark code. 

Spark will be running in a local mode, that is there will not be a seperate Master and Worker Spark processes, just a single JVM process.

Both Spark and Jupyter Notebook will be running in a Docker container. Terraform code will automaticall create an Azure Linux VM using and immediately run that container and we will be able to access Jupyter Notebook through a browser and start running Spark code.

Once we have Spark code prepared we will be able to submit a Spark job to a Kubernetes cluster to execute it in a distributed way.

We will use the same Docker image for running Spark in a local mode and Jupyter Notebook, and for running Spark jobs in a distributed way on a Kubernetes cluster. 

For running Spark jobs on a Kubernetes cluster we will use the SparkApplication manifest. It can be run manually from a terminal using the kubectl or it can be also trigerred by Airflow.



# Repository guide
Here is a guide describing how to use this code.

## Creating Azure Linux VMs
In order to create VMs using Terraform we need to run the following commands:
>- terraform init # only when running Terraform for the first time in this repository
>- terraform plan -out main.tfplan
>- terraform apply main.tfplan

In order to destroy all the created resources in Azure we need to run the following commands:
>- terraform plan -destroy -out main.destroy.tfplan
>- terraform apply main.destroy.tfplan

Creating Azure resources by running 'terraform apply' command might take around 10 minutes. Once this command is executed, that means that Terraform has already created Linux VMs and executed on them bash scripts which cofigured on them Kubernetes and ran a Docker container with Spark and Jupyter Notebook. Jupyter Notebook and Spark will be ready to use but the Kubernetes cluster will not be running yet.

The next section 'Setting up a Kubernetes cluster' describes how to start the Kubernetes cluster, and 'Accessing Jupyter Notebook' section describes how to access a Jupyter Notebook through a browser.

## Setting up a Kubernetes cluster
When we run 'terraform apply', Terraform performs the initial setup of Kubernetes by executing bash scripts from the bash_scripts folder on both VMs:
- The 'vm1_...' script configures the VM1 (Maste Node)
- The 'vm2_...' script configures the VM2 (Worker Node)

But the cluster is not running yet after that, we need to start it manually.

Those bash scripts will save the join command in the /home/username/k8s_join_workers.txt file on the VM1 (where username is specified by the vm_username Terraform variable). We need to copy that command and execute it on the VM2.

In order to start the Kubernetes cluster we need to follow those steps:
- connect from our local computer to the VM1 using SSH
- copy the join command from the ~/k8s_join_workers.txt file (run 'cat k8s_join_workers.txt' in terminal to display that command)
- connect from our local computer to the VM2 using SSH
- execute the copied join command on the VM2 (using sudo, so that is "sudo <copied_command>"). That will add the VM2 to the Kubernetes cluster.

In order to confirm that the cluster is running we can do the following things:
- Run the 'kubectl get pods -n kube-system' command to see if all the required system Pods are running. All the listed Pods there should have status 'Running'. It might take some time to run all the Pods, some of them might have the 'In progress' status at the beginning.
- Run the 'kubectl get nodes' command. It should list two nodes 'master' and 'worker1' with the 'Ready' status. Again it might take some time. Before both nodes get status 'Ready' the previous command must show that all the system Pods are Running.

More information about how to connect to both VMs using SSH is in the 'Connecting to the created VMs from our local computer through SSH' section of this documentation.

## Accessing Jupyter Notebook
Jupyter Notebook will be started on the VM1 after running 'terraform apply', by executing a bash script by Terraform. To access the Jupyter Notebook use the URL:
>public_ip_address_vm_1:8888

Where public_ip_address_vm_1 is the Terraform output. More information about how to get this output is in the 'Terraform outputs' section of this documentation.

Password to the Jupyter Notebook is specified by the Terraform variable jupyter_notebook_password ('admin' by default).

## Starting Spark session
Once we are in the Jupyter Notebook, we can create a Spark session in the following way:

```
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName("SparkTest") \
    .master("local[*]") \
    .getOrCreate()
```

Where `master("local[*]")` indicates that we want to run Spark in a local mode.

If we want to run the Spark script in Kubernetes in a distributed way, then we need to create Spark session like that:
```
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName("SparkTest") \
    .getOrCreate()
```

So we don't specify here the master. It will be added automatically by the Kubernetes Spark Operator.

## Running Spark script on Kubernetes
We can either use the prepared testing script saved at /home/username/notebooks/my_script.py at host VM or we can create our own script through Jupyter Notebook.

The /home/username folder is the home folder for a user which we will use to connect through SSH to the VM. The 'username' is specified by the Terraform variable vm_username, 'azureadmin' by default.

In order to run a Spark script on Kubernetes we need to deploy a SparkApplication resource using prepared manifest:
>kubectl apply -f ~/k8s/spark_application.yaml

In the ~/k8s/spark_application.yaml manifest, in the spec > mainApplicationFile field is specified a path to the script which we want to run. That is a path inside a Spark Driver Pod's container to which we mount a volume linked to a folder on a host. 

More information about how this works is in other sections of this documentation:
- 'SparkApplication volumes and volumeMounts'
- 'Workflow - developing code in Jupyter and deploying on Kubernetes'
- 'Docker image for Spark and Jupyter Notebook' (especially the 'Docker image - Bind mounting' subsection)





# Prerequisites
Before we start using this code we need to perform steps described in the below subsections:
- Get an Azure subscription
- Install and configure Terraform on our computer
- Create the terraform.tfvars file and specify Terraform variables there

## Azure subscription
We need to have a subscription on the Azure platform portal.azure.com.

## Terraform configuration
We need to configure properly Terraform on our computer so it can create resources in our Azure subscription, it is described here: [developer.hashicorp.com](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build).

## Terraform variables
Before using this code we need to create terraform.tfvars file which look like terraform-draft.tfvars file in the same location. It is described there what values to provide. We are assigning there values to variables from the variables.tf file located in the same folder. In the variables.tf we can also find descriptions of those variables. We need to assign values only for those variables which doesn't have assigned the default value.





# Code explanation
Here is a brief explanation of how this code works.

## Workflow - developing code in Jupyter and deploying on Kubernetes
We are running Jupyter Notebook and Spark in a Docker container. That allows us to develop Spark scripts and save them on the host (using bind mounting).

Once we have a Spark script prepared, we can run it on Kubernetes using the SparkApplication Kubernetes resource and the same Docker image which we used for running Jupyter Notebook and Spark.

The workflow of developing code in Jupyter Notebook and deploying it on Kubernetes looks like that:
- Run the container which runs Jupyter Notebook and Spark to develop Spark script
- Save it as the my_script.py file. It will be saved in both:
    - The container in the /home/spark/notebooks folder
    - On the host in the /home/username/notebooks folder

    That's thanks to the bind mounting.
- We deploy the SparkApplication resource which uses the /home/username/notebooks folder on the node as a mounted volume for created container. This way Pods created by the Spark Operator has access to the created script my_script.py and it runs that script on the Kubernetes cluster.



## Docker image for Spark and Jupyter Notebook
Here is more information about Docker image used for using Spark and Jupyter Notebook.

### Bash script creating the Dockerfile and running a container
The terraform_linux_vm/bash_scripts/vm1_configure bash script is automatically executed by Terraform on the VM1 after it is created and it performs the following actions on the VM1:
- creates a Dockerfile
- creates an entrypoint.sh script used in that Dockerfile
- builds an image from it and pushes it to the ACR
- runs a container

Running container:
- Contains Spark setup to run in a local mode
- Runs a Jupyter Notebook which will be accesible through a browser

### Docker image usage
In that container we create the /home/spark/notebooks folder which will contain all the scripts created in the Jupyter Notebook. From that folder we are starting the Jupyter Notebook (so content of that folder will be visible on the website).

The same Docker image will be used to run Spark jobs on Kubernetes. In that case it doesn't start a Jupyter Notebook. Whether that Docker image starts a Jupyter Notebook or not depends on a value of the LAUNCH_JUPYTER environment variable (true or false) which is used in the entrypoint.sh file.

That Docker image 

### Docker image - Bind mounting
The /home/spark/notebooks folder from a container will be mounted to the /home/username/notebooks folder on the host. This way all the notebooks which we create in Jupyter Notebook will be saved on host in the /home/username/notebooks folder, and the same folder will be used as a mounted volume for Kubernetes SparkApplication resource.

This way we can develop scripts in Jupyter Notebook, they will be saved on host and then they will be ran on the Kubernetes cluster using the SparkApplication resource. More details about that workflow is in the 'Workflow - developing code in Jupyter and deploying on Kubernetes' section of this documentation.



## Setting up a Kubernetes cluster - details
We are using here the Calico as the Container Network Interface (CNI).

## Submitting Spark jobs to Kubernetes
Here is more information about tools used for running Spark scripts on Kubernetes.

### Setting up Spark Operator and preparing SparkApplication manifest
We are using the Spark Operator and SparkApplication resource in order to submit Spark Jobs.

Bash script vm1_configure.tftpl executed by Terraform is creating a SparkApplication YAML manifest which will be used submitting our Spark jobs. We specify there which script we want to run.

We are using the Helm package manager to install the Spark Operator needed to submit Spark jobs to Kubernetes.

### Deploying SparkApplication resource
After deploying the SparkApplication resource, Spark Operator will notice that, create a Spark Driver Pod, and Driver Pod will create Spark Executors Pods.

Spark Operator and Spark Driver Pod need a Service Account with proper permissions for authentication for managing Pods. Spark Operator will have already assigned a Service Account with proper permissions after installing it with Helm. For Spark Driver we are creating a new Service Account in the vm1_configure.tftpl bash script.

### SparkApplication volumes and volumeMounts
In the SparkApplication YAML manifest, in the spec > mainApplicationFile field, we are specifying what script we want to run. That is a path in the Spark Driver Pod's container. That path is mounted to a volume which is linked to the path on a host.

For example if we have a SparkApplication YAML manifest like that:
```
spec:
    mainApplicationFile: "local:///opt/spark/scripts/my_script.py" # Spark script to run. That is a path inside the Spark Driver Pod's container.
volumes:
  - name: scripts-volume
    hostPath:
      path: /home/${username}/notebooks   # path on the Kubernetes node (VM) with Spark scripts.
      type: Directory
driver:
    volumeMounts:
     - name: scripts-volume
       mountPath: /opt/spark/scripts  # path inside the Spark Driver Pod's container with Spark scripts.
```
That means that the /home/${username}/notebooks path on a node (host VM) is linked to a volume called scripts-volume and that volume is linked to the /opt/spark/scripts path in the Spark Driver Pod's container.

So all the files from the /home/${username}/notebooks folder on a node will be available in the /opt/spark/scripts folder in the Spark Driver Pod's container.

So the above example will run the /home/${username}/notebooks/my_script.py file from the node (host VM). 

We can develop Spark scripts in Jupyter Notebook and run them on kubernetes. More details about that workflow is in the 'Workflow - developing code in Jupyter and deploying on Kubernetes' section of this documentation.

## Creating Azure resources with Terraform
In the terraform_linux_vm folder we have terraform code which performs the following actions:
- Creates our VMs.
- Configures on the created VMs Spark and Kubernetes by executing bash scripts on them.
- Creates an ACR for saving Docker images.

We have there the main.tf file which creates all the resources. This file uses modules defined in the terraform_linux_vm > modules folder. Each module is dedicated to creating one type of resource in Azure.

## Terraform outputs
Terraform creates the following outputs: 
- 'public_ip_address_vm_1' and 'public_ip_address_vm_2' - Public IP addresses of both VMs
- acr_sp_id and acr_sp_password - Credentials used for authentication to ACR.

They are printed at the end of executing 'terraform apply' and they can be accessed by running the command:
>terraform output

## ACR setup
ACR is created using the terraform_linux_vm > modules > acr module. We are also creating a Service Principal which will be used for authentication to it using the service_principal module.

## VMs setup
The terraform_linux_vm > modules > linux_vm > main.tf script contains code creating VMs.

We are creating VMs of specified size (Standard_B2ms by default) and we create on them a new user specified by the vm_username variable.

## VMs network setup
We are creating networks (Vnets) for our VMs. They will get assigned public IP addresses and we can define for them security rules.

In the terraform_linux_vm > modules > networks > main.tf we are defining security rules for our VMs network. We open there specific ports required to run Kubernetes, to be able to connect through SSH and to access a Jupyter Notebook from a browser on our local computer.

## Bash scripts for configuring VMs
After creating VMs using Terraform we are executing on them bash scripts using the azurerm_virtual_machine_extension Terraform resource which uses Azure VM Extension.

Those bash scripts are configuring Kubernetes, Spark and Jupyter Notebook. They are saved in the terraform_linux_vm > bash_scripts. They perform the following actions:
- **vm1_configure.tftpl** - script executed on the VM1. It performs the following actions:
    - Edit the /etc/hosts file - It assigns hostnames to the private IP addresses of both VMs. Hostnames are taken from the Terraform variable 'hostnames'.
    - Saves a SSH private key - Which will be used for connecting from the VM1 to the VM2
    - Creates a Dockerfile, builds an image from it, pushes it to ACR and runs a container which contains Spark setup to run in a local mode and runs a Jupyter Notebook
    - Configures Kubernetes (that VM acts as a Master node)
- **vm2_configure.tftpl** - script executed on the VM2. It performs the following actions:
    - Edit the /etc/hosts file - It assigns hostnames to the private IP addresses of both VMs. Hostnames are taken from the Terraform variable 'hostnames'.
    - Add SSH public key to the authorized keys - Which will be used for connecting from the VM1 to the VM2
    - Configures Kubernetes (that VM acts as a Worker node)

Those bash scripts can't be used on their own on a Linux machine since they are rendered using the Terraform templatefile function first before execution. More information about that here [developer.hashicorp.com](https://developer.hashicorp.com/terraform/language/functions/templatefile).

We are inserting into those scripts variables specified in the templatefile function (what can be found in the terraform_linux_vm > main.tf script) and also we are using there escape sequences. More information about that here [developer.hashicorp.com](https://developer.hashicorp.com/terraform/language/expressions/strings).

## Connecting to the created VMs from our local computer through SSH
The Terraform code will generate SSH keys pair, save the private key on our local computer and add the public key to the authorized keys on the created VMs.

Then we can connect to the created VMs by using this command on our local computer:
>ssh username@ip_address

Here is described how to get values needed for SSH connection:
- **ip_address** - In order to get the ip_address values for both created VMs we need to use the Terraform outputs called 'public_ip_address_vm_1' and 'public_ip_address_vm_2'. More info about those outputs in the 'Terraform outputs' section of this documentation.
- **username**- The username value is the same as the one defined in the terraform.tfvars file for the vm_username variable (or the default one defined in the variables.tf).

The ssh_path Terraform variable specifies where on our local computer the private key will be saved. The recommended one for Windows is C:\\Users\\username\\.ssh\\id_rsa (if we save the private key here then we don't need to provide a path to that key when running the 'ssh' command).

We are using the modules/ssh module which generates SSH keys as strings which are saved on our local computer and created VMs.





# Code developments notes
In this section are some important notes regarding why this code was developed this way and they might be useful when trying to modify this code or use a part of it for other purposes.

## Spark Operator webhook
I was trying to use webhook for Spark Operator but it doesn't work. Kubernetes API is not able to communitace with that webhook.

Webhook allows us to provide some additional parameters for Driver and Executors Pods. The same can be also obtained using a Pod Template File.

for example adding tolerations or credentials for pulling Docker images from container registry.

## Pod Template File
I was trying to mount a Pod Template File to SparkApplication in order to specify tolerations and imagePullSecrets fields but it doesn't work. 

Finally I managed to include tolerations and imagePullSecrets in the SparkApplication manifest without Pod Template File.