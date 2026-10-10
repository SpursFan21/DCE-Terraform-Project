terraform {
  backend "s3" {
    bucket       = "dce04-terraform-state-488510448462"
    key          = "infrastructure/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}