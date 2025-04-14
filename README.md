# Module Basics
- Modules are like functions which can be called in another function.
- We are starting off with the webserver cluster we created in chpt3-
- Here we have MOVED all the code inside the <stage/services/webserver-cluster> to create the module.
- Modules does not contain the provider block
- Providers should only be configured in root modules and not in reusable modules.
- Also, no backend configuration for modules, only root module.
- After creating a module, you can reuse it elsewhere with the following syntax:
    module "<NAME>" {
        source = "<SOURCE>"
        [CONFIG ...]
    }

WHERE:
   NAME -> an identifier you can use throughout the terraform code
to refer to this module.
   SOURCE -> the path where the module code can be found.
   CONFIG -> consists of arguments that are specific to that module.

# Code reuse in multiple environments:
For example:
- We can create a new file in <terraform-up-and-running-by-Yev-Brikman\chpt4-reusable-infra-with-terraform-modules\module-example\stage\services\webserver-cluster\main.tf> as follows:

provider "aws" {
    region = "us-east-1"
    profile = "terraform"
}

module "webserver_cluster" {
    source = "..\..\..\modules\services\webserver-cluster
}

- We can also reuse the same module in prod:

provider "aws" {
    region = "us-east-1"
    profile = "terraform"
}

module "webserver_cluster" {
    source = "..\..\..\modules\services\webserver-cluster
}

[BestPractice]
Whenever you add a module to your terraform configurations or modify your source parameter of a module, you need to run the init command before terraform plan or apply:
# terraform init:
    - initializes/installs providers/plugins
    - initializes/configures your backends
    - downloads modules 

# USER-DATA IN MODULES
- We updated our launch template configuration resource.
- The key change is adding ${path.module}/ before the file name. This tells Terraform to look for the file in the module's directory rather than the root module directory.

- ${path.module} is a special Terraform variable that contains the filesystem path of the module where the expression is placed. This ensures Terraform can find the user-data.sh file in the correct location, regardless of where the module is being called from.

# ADDING CONFIGURABLE INPUTS TO MODULES
- For modules to behave differently in different environments, you must not hard-code names. Else, when reused you start getting <names conflict errors>.

# Module Inputs 
- We use input parameters to make modules configurable.
- We start by creating variables.tf and adding some new input variables.

<..\..\..\modules\services\webserver-cluster\variables.tf>

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}

# The idea here is to have a uniform prefix for all resource names # in each environment. This will be perculiar to each environment # as it will be define under the module CONFIG in each environment
variable "cluster_name" {
    description = "The name to use for all the cluster resources"
    type = string
}

variable "db_remote_state_bucket" {
    description = "The name of the S3 bucket for the database's remote state"
    type = string
}

variable "db_remote_state_key" {
    description = "The path for the database's remote state in S3"
    type = string
}

# Usage:
- Go through the modules main.tf, and use var.cluster_name to update the hardcoded names of all resources, including the tags: 
See examples below:
<Note how and where an interpolation expressions are used>

    tag {
            key = "Name"
            value = "${var.cluster_name}-asg"
            propagate_at_launch = true
        }

data "terraform_remote_state" "db" {
    backend = "s3"
    config = {
        bucket = var.db_remote_state_bucket
        key = var.db_remote_state_key
        region = "us-east-1"
    }
}

# Now you can set the values of these variables in the stage/prod environments module CONFIG.

module "webserver_cluster" {
    source = "../../../modules/services/webserver-cluster"

    cluster_name = "webservers-stage"
    db_remote_state_bucket = "zoe-terraform-running-state"
    db_remote_state_key = "stage/data-stores/mysql/terraform.tfstate"
    server_port = 8080
    instance_type = "t2.micro"
    min_size = 1
    max_size = 3
}

# MODULE LOCALS
- Local values allow you to assign a name to any  Terraform expression and to use that name throughout the module.
- These names are only visible within the module and has no impact on other modules.
- Useful when you don't want want expose input variables as configurable inputs.
- Instead of using input variables, you define them as local values.
- These local values can be used anywhere within the module.
- you cannot override these local values anywhere outside the module where it resides.

- How do we define local values? <Inside locals block>:
- We either add a locals block inside the module's main.tf or create a locals.tf
[locals]

locals {
    http_port = 80
    any_port = 0
    any_protocol = "-1"
    tcp_protocol = "tcp"
    all_ips = ["0.0.0.0/0"]
}

- How do we read the value of module locals? <Use a local reference>:
[syntax]
local.<NAME>

- We will replace all associated local values defined above in our webserver_cluster module resources. 
# Example:
- In the modules main.tf, we will read the above defined values as follows:
        local.http_port           -- replaces 80
        local.any_port            -- replaces 0
        local.any_protocol        -- replaces -1
        local.tcp_protocol        -- replaces tcp
        local.all_ips             -- replaces 0.0.0.0/0

resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
    # Allow inbound HTTP requests
    ingress {
        from_port = local.http_port
        to_port = local.http_port
        protocol = local.tcp_protocol
        cidr_blocks = local.all_ips
    }

    # Allow all outbound requests
    egress {
        from_port = local.any_port
        to_port = local.any_port
        protocol = local.any_protocol
        cidr_blocks = local.all_ips
    }
}
- Locals make your code easier to read and maintain.

# MODULE OUTPUTS
================
- What if you want to access the output from a module i a different module.
- Similar to how functions return values. Modules also return values (output variables).

[Use-case scenario]:
- We want to implement scheduled action feature of our ASG in the 
prod env. so we can control the surge in demand during business hours.
- We will define this resource in the prod environment, but it will use output from the webserver_cluster module.
<Resource: aws_autoscaling_schedule>
- Add the following two aws_autoscaling_schedule resources to:
terraform-up-and-running-by-Yev-Brikman\chpt4-reusable-infra-with-terraform-modules\module-example\prod\services\webserver-cluster\main.tf

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
    scheduled_action_name = "scale-out-during-business-hours"
    min_size = 2
    max_size = 10
    desired_capacity = 10
    recurrence = "0 9 * * *"
    autoscaling_group_name = module.webserver_cluster.asg_name
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
    scheduled_action_name = "scale-in-at-night"
    min_size = 2
    max_size = 10
    desired_capacity = 2
    recurrence = "0 17 * * *"
    autoscaling_group_name = module.webserver_cluster.asg_name
}

- For us to get the value of the <autoscaling_group_name>, we need to define output variable in the module webserver_cluster:
outputs.tf

output "asg_name" {
  value = aws_autoscaling_group.example.name
  description = "The name of the Auto Scaling Group"
}

- We will then "pass through" the above output in the <prod environment> outputs.tf as follows:

output "asg_name" {
    value = module.webserver_cluster.asg_name
}

# MODULE GOTCHAS
[File Path]
- By default, if you are using templatefile function in the root module, terraform interprets file path relative to the current working directory (cwd/pwd).
- If you are using templatefile function in a module that's defined in a separate folder (reusable module), then terraform behaves differently:
  - You will need to make use of <path reference>
    [path.<TYPE>]
    path.module  # Returns the filesystem path of the module where the expression is defined.
    path.root  # Returns the filesystem path of the root module
    path.cwd  # Returns the filesystem path of the current working directory. May be same as root.

[Usage] =>

 user_data = templatefile("${path.module}/user_data.sh", {

})

[Inline Blocks]
- An inline block is an argument you set within a resource block of the format:

        resource "xxx" "yyy" {
            <NAME> {             # Name of the inline block, eg ingress
                [CONFIG...]  # One or more argument specific to the inline block
            }
        }

Some resources can be define either as an inline or directly but not both.
- Example:
 - With the security_group_resource, you can define "ingress" and "egress" rules as either inline blocks or separately using "aws_security_group_rule" resources. Both can't have a mix of both options.

- <Best Practices>
- Better to use separate resource blocks than inline.
- Benefit of separate resources, is that it can be added anywhere whereas, an inline block can only be added within the module that creates a resource.
- Using solely separate resource makes your module more flexible and configurable.

[Implementation]
- Let's rewrite the aws_security_group resource in the webserver_cluster module and separate the ingress and egress rules into separate resources.

resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
    # Allow inbound HTTP requests
    ingress {
        from_port = local.http_port
        to_port = local.http_port
        protocol = local.tcp_protocol
        cidr_blocks = local.all_ips
    }

    # Allow all outbound requests
    egress {
        from_port = local.any_port
        to_port = local.any_port
        protocol = local.any_protocol
        cidr_blocks = local.all_ips
    }
}
[Transformed]
resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
    type = "ingress"
    security_group_id = aws_security_group.alb.id

        from_port = local.http_port
        to_port = local.http_port
        protocol = local.tcp_protocol
        cidr_blocks = local.all_ips
 }

resource "aws_security_group_rule" "allow_all_outbound" {
    type = "egress"
    security_group_id = aws_security_group.alb.id
    
        from_port = local.any_port
        to_port = local.any_port
        protocol = local.any_protocol
        cidr_blocks = local.all_ips
}

- For this to work, we need to export the ID of the aws_security_group as an output variable in 
modules/services/webserver_cluster/output.tf:


- <Now the module is more flexible and configurable>
- If we want to expose more ports, for instance in staging env for testing, we can do so as shown below:
stage/services/webserver_cluster/main.tf:
Add this block:
resource "aws_security_group_rule" "allow_testing_inbound" {
    type = "ingress"
    security_group_id = module.webserver_cluster.alb_security_group_id 

    from_port = 12345
    to_port = 12345
    protocol = "tcp"
    cidr_blocks = [0.0.0.0/0"]
}
- Note how we are extracting the security_group_id from the output.tf variable
- If we had defined even a single ingress rule using inline block in the module, this code will not work.
- This logic of inline block also applies to some other resources like:
   -    aws_security_group and aws_security_group_rule
   -    aws_route_table and aws_route
   -    aws_network_acl and aws_network_acl_rule

# MODULE VERSIONING
===================
- Terraform supports the following source parameters while working with module:
    -   file paths (local filepath)
    -   Git URLs
    -   Mercurial URLs
    -   Arbitrary HTTP URLs

Module versioning is useful because it makes it possible for use to use one version of the same module for staging and a different version for production. If a new version is tested in staging and deployed to production, we can roll back to previous working version if it misbehaves.

- <How to implement versioned module>
[STEPS]
- Put the code for the module in a separate Git repository
- Set the source parameter to that Git repository's URL.
This means our Terraform code will be spread out across at least two repositories.
    1. modules
        -This repo defines reusable modules. Think of each module as a blueprint that defines a specific part of your infrastructure.

    2. live
        - This repo defines the live infrastructure you're running in each environment (stage, prod, etc).
        - Think of this as the "houses" you built from the "blueprints" in the modules repo.

- We will move the stage, prod and global folders to a new folder called live.
- Configure live and modules folders as separate git repositories

cd modules
    git add .
    git commit -m "Made some changes to webserver-cluster"
    git push origin main


git tag -a "v0.0.1" -m "First release of webserver-cluster module for staging"
git push --follow-tags

<Setting "Source Parameter">
- Now you can use versioned module in both staging and production by specifying a Git URL in the source parameter.
- For Git Public Repo: https://github.com/steph-nnamani/modules.git 
Here is what it will look like inside the live/stage/services/webserver-cluster/main.tf

module "webserver_cluster" {
    source = "github.com/steph-nnamani/modules///services/webserver-cluster?ref=v0.0.1"

    cluster_name = "webservers-prod"
    db_remote_state_bucket = "zoe-terraform-running-state"
    db_remote_state_key = "prod/data-stores/mysql/terraform.tfstate"
    server_port = 8085
    instance_type = "t2.micro"
    min_size = 2
    max_size = 2 
}

- The ref parameter allows you to specify a particular Git commit via its "sha1 hash", "a branch name", or "specific git tag"
- Git tags as version numbers for modules: a tag is just a pointer to a commit, but it's more friendlier, readable name than sha! hash.

- For Private Git Repos:
    - You need to give Terraform a way to authenticate to that Github Repository.
    - ssh auth ia an option
    - Each developer can create an ssh key, associate it with their Git user, add it to ssh-agent, and Terraform will authomatically use that key for authentication if you use an SSH source URL.

    The source URL should be like:
    git@github.com:<OWNER>/<REPO>.git//<PATH>?ref=<VERSION>
    source = "git@github.com:steph-nnamani/modules.git//services/webserver-cluster?ref=v1.0.0"
    
    cd modules
    git add .
    git commit -m "Made some changes to webserver-cluster"
    git push origin main

    - Create a new tag in the modules repo:
    git tag -a "v1.0.0" -m "First release of 
    webserver-cluster Module for production"
    git push --follow-tags

- We can use v0.0.2 for production and 

# Enable long paths in Windows:
- Windows has a path length limitation

Open PowerShell as Administrator

Run this command:
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
