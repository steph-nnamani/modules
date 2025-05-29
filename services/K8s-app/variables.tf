variable "name" {
    description = "The name to use for all resource created by this module"
    type = string
}

variable "image" {
    description = "The image to use for the container"
    type = string
}

variable "container_port" {
    description = "The port to expose on the container"
    type = number
}

variable "replicas" {
    description = "The number of replicas to create"
    type = number
}

variable "environment_variables" {
    description = "The environment variables to set for the app"
    type = map(string)
    default = {}
}