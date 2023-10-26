variable "bucket_name" {
  description = "The name of the S3 bucket"
  default = "pulse-data-bucket"
}

# variable "vpc_id" {
#   description = "The vpc id"
#   type = string
# }

variable "subnet_id" {
  description = "This is the subnet id"
  type = string
}

variable "security_group" {
  description = "Security group ID" 
  type = string
}