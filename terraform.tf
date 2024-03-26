## Configuration
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
## -- END Configuration

## Variables
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "demo"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
}
## -- END Variables

## VPC 
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = merge({
    Terraform = "true"
    Owner     = data.aws_caller_identity.current.user_id
  }, var.tags)
}
## -- END VPC

## EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    system = {
      min_size     = 2
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  node_security_group_additional_rules = {
    # allow connections from EKS to the internet
    egress_all = {
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # allow connections from EKS to EKS (internal calls)
    ingress_self_all = {
      protocol  = "-1"
      from_port = 0
      to_port   = 0
      type      = "ingress"
      self      = true
    }
  }

  tags = merge({
    Terraform                = "true"
    Owner                    = data.aws_caller_identity.current.user_id
    "karpenter.sh/discovery" = var.cluster_name
  }, var.tags)
}

## -- END EKS Cluster


## Karpenter

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.8.4"

  cluster_name = module.eks.cluster_name

  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge({
    Terraform = "true"
    Owner     = data.aws_caller_identity.current.user_id
  }, var.tags)
}

## -- END Karpenter

## Outputs 

output "info" {

  value = jsonencode({
    eks = {
      cluster_name    = module.eks.cluster_name
      cluster_version = module.eks.cluster_version
    }
    karpenter = {
      queue_name         = module.karpenter.queue_name
      iam_role_arn       = module.karpenter.iam_role_arn
      node_iam_role_name = module.karpenter.node_iam_role_name
    }
  })

}


## -- End Outputs 
