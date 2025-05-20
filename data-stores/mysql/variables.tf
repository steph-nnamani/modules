variable "instance_class" {
  type = string
  description = "Instance class for the RDS instance"
  default = "db.t3.micro"
}

variable "rds" {
  type = string
  description = "prefix name to distinguish of the RDS instance env"
  default = null # "prodawsrds" does not accept '-' hyphen
 }

variable "db_name" {
  type = string
  description = "Name of the database"
  default = null 
}

variable "db_username" {
  type = string
  sensitive = true
  description = "Username for the database"
  default = null
}
variable "db_password" {
  type = string
  sensitive = true
  description = "Password for the database"
  default = null
}

variable "backup_retention_period" {
  type = number
  description = "Days to retain backups. Must be > 0 to enable replication."
  default = null
}
variable "replicate_source_db" {
  type = string
  description = "If specified, replicate the RDS database at the given ARN"
  default = null
}