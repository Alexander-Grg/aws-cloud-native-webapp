terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

  }
}