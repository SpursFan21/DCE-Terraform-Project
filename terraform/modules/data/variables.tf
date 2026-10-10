variable "project_name" {
  description = "Project naming prefix"
  type        = string
}

variable "bucket_suffix" {
  description = "Unique suffix for globally unique S3 bucket names"
  type        = string
}