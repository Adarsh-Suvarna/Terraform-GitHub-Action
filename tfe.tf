terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
  cloud {
    hostname     = "terraform.adarshasuvarna.in"
    organization = "Niveus-Solutions-Pvt-Ltd"

    workspaces {
      name = "Terraform-GitHub-Action"
    }
  }
}

provider "google" {
  region = "asia-south1"
}