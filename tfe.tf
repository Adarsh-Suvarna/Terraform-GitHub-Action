terraform {
  cloud {
    hostname = "terraform.adarshasuvarna.in"
    organization = "Niveus-Solutions-Pvt-Ltd"

    workspaces {
      name = "Terraform-GitHub-Action"
    }
  }
}