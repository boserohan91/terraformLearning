variable "subnet_values" {
    description = "Object for CIDR block and name of subnet"
    type = list(object({
        cidr_block = string
        name = string
    }))
}

variable "web-server-private-ips" {
  description = "Holds private ip's required for the webserver"
  type = list(string)
  default = ["10.1.2.65"]
}

#######################################
#
# AWS Access key variables
#
#######################################

# DO NOT MENTION access key values here
variable "access_key_value" {
  description = "Access key value for AWS"
  type = string
}

# DO NOT MENTION secret access key values here
variable "secret_access_key_value" {
  description = "Secret access key value for AWS"
  type = string
}