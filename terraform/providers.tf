provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "DCE04-MultiCloud"
      Environment = "Assessment"
      ManagedBy   = "Terraform"
    }
  }
}