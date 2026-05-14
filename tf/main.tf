terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

module "us_east_cluster" {
  source    = "./modules/region_cluster"
  providers = { aws = aws.us_east_1 }

  vpc_cidr        = "10.1.0.0/16"
  tailscale_key   = var.tailscale_key
  peer_datacenter = "us-west-2"
}

module "us_west_cluster" {
  source    = "./modules/region_cluster"
  providers = { aws = aws.us_west_2 }

  vpc_cidr        = "10.2.0.0/16"
  tailscale_key   = var.tailscale_key
  peer_datacenter = "us-east-1"
}

locals {
  regional_clusters = {
    "us-east-1" = module.us_east_cluster
    "us-west-2" = module.us_west_cluster
  }
}

output "regional_alb_dns" {
  description = "ALB DNS name per region"
  value       = { for region, c in local.regional_clusters : region => c.alb_dns_name }
}

output "global_accelerator_dns" {
  description = "Global Accelerator anycast DNS name (use this as your primary entry point)"
  value       = aws_globalaccelerator_accelerator.nomad.dns_name
}

output "global_accelerator_ips" {
  description = "Static anycast IPs assigned to the Global Accelerator"
  value       = aws_globalaccelerator_accelerator.nomad.ip_sets[*].ip_addresses
}
