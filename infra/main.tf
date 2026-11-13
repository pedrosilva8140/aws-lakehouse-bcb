# Versões do Terraform e dos provedores usados
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

# Região do projeto (fixada pela AWS para contas do Brasil)
variable "region" {
  default = "us-east-2"
}

# Liga/desliga os agendamentos diários (deixe false fora das demos)
variable "agendar" {
  default = false
}

provider "aws" {
  region = var.region
  # Etiqueta aplicada em todos os recursos, para achar tudo do projeto
  default_tags {
    tags = { projeto = "aws-lakehouse-bcb" }
  }
}

# Lê o ID da conta logada (usado no nome do bucket)
data "aws_caller_identity" "eu" {}