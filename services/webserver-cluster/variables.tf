variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
}

variable "cluster_name" {
    description = "The prefix name to use to use for all the cluster resources"
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

variable "instance_type" {
    description = "The type of EC2 Instances to run (e.g. t2.micro)"
    type = string
}

variable "instance_type_alternate" {
    description = "The alternative EC2 Instance types to run (e.g. t2.micro)"
    type = string
}

variable "min_size" {
    description = "The minimum number of EC2 Instances in the ASG"
    type = number
}

variable "max_size" {
    description = "The maximum number of EC2 Instances in the ASG"
    type = number
}

variable "custom_tags" {
    description = "Custom tags to set on the Instances in the ASG"
    type = map(string)
    default = {}
}

variable "enable_autoscaling" {
  description = "If set to true, enable  auto scaling"
  type = bool
}

variable "ami" {
    description = "The AMI to run in the EC2 Instances"
    type = string
    default = "ami-0866a3c8686eaeeba"
}

variable "server_text" {
    description = "The text the web server should return"
    type = string
    default = "Welcome, To My World!!"
}

variable "on_demand_base_capacity" {
    description = "The number of on demand instances"
    type = number
    default = 1
}

variable "on_demand_percentage_above_base_capacity" {
    description = "The percentage of on demand instances above base"
    type = number
    default = 50
}

variable "spot_allocation_strategy" {
    description = "The allocation strategy for spot instances"
    type = string
    default = "lowest-price" # Options: price-capacity-optimized/capacity-optimized/diversified
}