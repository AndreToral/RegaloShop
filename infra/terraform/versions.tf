// Configuración de versiones y proveedores requeridos
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "regaloshop-tfstate"
    key            = "regaloshop/terraform.tfstate"
    # Si usas workspaces, puedes habilitar:
    # workspace_key_prefix = "regaloshop"
    region         = "us-east-1"
    dynamodb_table = "regaloshop-tflock"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

// Proveedor AWS parametrizado por región
provider "aws" {
  region = var.region
}
