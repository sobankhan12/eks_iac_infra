terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }

  }
}
provider "aws" {
  region  = var.aws_region
  #profile = var.aws_profile_name
}

data "aws_availability_zones" "available" {}

# Not required: currently used in conjunction with using
# icanhazip.com to determine local workstation external IP
# to open EC2 Security Group access to the Kubernetes cluster.
# See workstation-external-ip.tf for additional information.
provider "http" {}
provider "helm" {

}
provider "kubectl" {
  alias = "soban"
}
# provider "kubernetes" {

# }
# provider "kubectl" {
#   # Configuration options
# }
