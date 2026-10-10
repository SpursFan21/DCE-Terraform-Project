
variable "project_id" {
  description = "Google Cloud project used for disaster recovery."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique GCS bucket name."
  type        = string
}

variable "location" {
  description = "Google Cloud Storage bucket location."
  type        = string
  default     = "AUSTRALIA-SOUTHEAST1"
}
