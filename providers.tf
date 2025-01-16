
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
    default_tags {
      tags = {
        Name        = "Satisfactory"
      }
    }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
