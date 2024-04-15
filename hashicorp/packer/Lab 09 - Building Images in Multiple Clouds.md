# Lab: Building Images in Multiple Clouds
This lab will walk you through updating your Packer Template to build images across AWS and Azure.

Duration: 30 minutes

- Task 1: Update Packer Template to support Multiple Clouds
- Task 2: Specify Cloud Specific Attributes
- Task 3: Validate the Packer Template
- Task 4: Build Image across AWS and Azure

### Task 1: Update Packer Template to support Multiple Clouds
Packer supports seperate builders for deploying images accross clouds while allowing for a single build workflow.

### Step 1.1.1

Update your `aws-linux.pkr.hcl` file with the following Packer `required_plugins` block to use the `azure` plugin.

```hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}
```

In addition, update the `aws-linux.pkr.hcl` file with the following Packer `source` block for specifying an `azure-arm` image source.  This source contains the details for building this image in Azure.  We will keep the `aws-ebs` source untouched.

You will need to specify your own Azure credentials in the `client_id`, `client_secret`, `subscription_id` and `tenant_id`.  You will also need to create your own Azure resource group name called `packer_images` along with a `vm_size` that is available in your region. See Note below.

```hcl


source "azure-arm" "ubuntu" {
  client_id                         = "XXXX"
  client_secret                     = "XXXX"
  managed_image_resource_group_name = "packer_images" # You must create a resource group to save the images to
  managed_image_name                = "packer-ubuntu-azure-{{timestamp}}"
  subscription_id                   = "XXXX"
  tenant_id                         = "XXXX"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "16.04-LTS"

  azure_tags = {
    Created-by = "Packer"
    OS_Version = "Ubuntu 16.04"
    Release    = "Latest"
  }

  location = "East US"
  vm_size  = "Standard_A2"
}
```

> Note: (Optional) If you do not know how to create Azure credentials, you can log into the Azure portal shell and run the following options. 
> 
> Create a service principal: 
> ```shell 
> az ad sp create-for-rbac --role Contributor --name sp-packer-001
> ```
> ```shell
> Creating 'Contributor' role assignment under scope '/subscriptions/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
>The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli 'name' property in the output is deprecated and will be removed in the future. Use 'appId' instead.

```json
{
  "appId": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
  "displayName": "sp-packer-001",
  "name": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
  "password": "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
  "tenant": "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"
}
```

```text
Where: 
AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA is the Subscription ID
BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB is the Client ID
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC is the Client Secret
DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD is the Tenant ID
```

> Note: (Optional) List available sizes for Azure VMs

> ```shell
> az vm list-skus --location eastus --size Standard_A --output table 

> ```shell
> az vm list-sizes --location eastus --query "[? contains(name, 'Standard_A')]" --output table
> ```

> Use an appropriate size for the `vm_size` attribute.  If `Standard_A2` is not available consider `Standard_A2_V2`


> Note: Based on your the access of your Azure credentials you may need to create a Azure Resource Group to save your Packer Images
> ```shell
> az group create -l eastus -n packer_images
> ```

### Task 2: Specify Cloud Specific Attributes
The packer `build` block will need to be updated to specify both an AWS and Azure build.  This can be done with the updated `build` block:

```hcl
build {
  name = "ubuntu"
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu", 
  ]

  provisioner "shell" {
    inline = [
      "echo Installing Updates",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y nginx"
    ]
  }

  provisioner "shell" {
    only = ["source.amazon-ebs.ubuntu"]
    inline = ["sudo apt-get install awscli"]
  }

  provisioner "shell" {
    only = ["source.azure-arm.ubuntu"]
    inline = ["sudo apt-get install azure-cli"]
  }

  post-processor "manifest" {}

}
```

### Task 3: Rename and Validate the Packer Template
Now that the Packer template has been updated to be multi-cloud aware, we are going to rename the template to `linux.pkr.hcl`.  After refactoring and renaming our Packer template, we can auto format and validate the templatet via the Packer command line.

### Step 3.1.1

Initialize, format and validate your configuration using the `packer fmt` and `packer validate` commands.

```shell
packer init linux.pkr.hcl
packer fmt linux.pkr.hcl 
packer validate linux.pkr.hcl
```

### Task 4: Build a new Image using Packer
The `packer build` command is used to initiate the image build process across AWS and Azure.

### Step 4.1.1
Run a `packer build` for the `linux.pkr.hcl` template only for the Ubuntu build images.

```shell
packer build -only 'ubuntu*' linux.pkr.hcl
```

Packer will print output similar to what is shown below.  You should notice a different color for each cloud in which an image is being created.

```bash
packer build linux.pkr.hcl
ubuntu.amazon-ebs.ubuntu: output will be in this color.
ubuntu.azure-arm.ubuntu: output will be in this color.

==> ubuntu.azure-arm.ubuntu: Running builder ...
==> ubuntu.azure-arm.ubuntu: Getting tokens using client secret
==> ubuntu.azure-arm.ubuntu: Getting tokens using client secret
==> ubuntu.amazon-ebs.ubuntu: Prevalidating any provided VPC information
==> ubuntu.amazon-ebs.ubuntu: Prevalidating AMI Name: packer-ubuntu-aws-1620188684

...
...

==> Wait completed after 8 minutes 36 seconds

==> Builds finished. The artifacts of successful builds are:
--> ubuntu.amazon-ebs.ubuntu: AMIs were created:
eu-central-1: ami-06cb993373624ec00
us-east-1: ami-0c80e78a667406d87
us-west-2: ami-0dd51ccb6faf2588d

--> ubuntu.azure-arm.ubuntu: Azure.ResourceManagement.VMImage:

OSType: Linux
ManagedImageResourceGroupName: packer_images
ManagedImageName: myPackerImage
ManagedImageId: /subscriptions/e1f6a3f2-9d19-4e32-bcc3-1ef1517e0fa5/resourceGroups/packer_images/providers/Microsoft.Compute/images/myPackerImage
ManagedImageLocation: East US
```

##### Resources
* Packer [Docs](https://www.packer.io/docs/index.html)
* Packer [CLI](https://www.packer.io/docs/commands/index.html)
