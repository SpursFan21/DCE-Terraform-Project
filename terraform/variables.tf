variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "dce-project"
}