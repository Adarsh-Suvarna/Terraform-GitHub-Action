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
      name = "gcs-01"
    }
  }
}

provider "google" {
  region = "asia-south1"
}