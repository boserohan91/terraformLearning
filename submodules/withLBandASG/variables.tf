variable "aws_access_key" {
  description = "Variable for the aws secret access key"
  type = string
}

variable "aws_secret_access_key" {
  description = "Variable for the aws secret access key"
  type = string
}

variable "region" {
  description = "Holds the region name"
  default = "eu-central-1"
  type = string
}

variable "subnet-value-1" {
  description = "Holds the subnet name"
  default = "eu-central-1a"
  type = string
}

variable "subnet-value-2" {
  description = "Holds the subnet name"
  default = "eu-central-1b"
  type = string
}