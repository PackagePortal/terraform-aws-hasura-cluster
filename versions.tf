terraform {
  required_version = ">= 0.15"
}

provider "aws" {
  version = ">= 3.6"
  region  = var.region
}