terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.23.0"
    }
  }
}

provider "aws" {
  region     = "ap-northeast-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"

  tags = {
    Name = "fastcampus-ubuntu"
  }
}

module "vpc" {
  source  = "tedilabs/network/aws//modules/vpc"
  version = "0.24.0"

  name                  = "fastcampus"
  cidr_block            = "10.0.0.0/16"

  internet_gateway_enabled = true

  dns_hostnames_enabled = true
  dns_support_enabled   = true

  tags = {}
}

module "subnet_group__public" {
  source  = "tedilabs/network/aws//modules/subnet-group"
  version = "0.24.0"

  name                    = "${module.vpc.name}-public"
  vpc_id                  = module.vpc.id
  map_public_ip_on_launch = true

  subnets = {
    "${module.vpc.name}-public-001/az1" = {
      cidr_block           = "10.0.0.0/24"
      availability_zone_id = "apne2-az1"
    }
    "${module.vpc.name}-public-002/az2" = {
      cidr_block           = "10.0.1.0/24"
      availability_zone_id = "apne2-az2"
    }
  }

  tags = {}
}

module "subnet_group__private" {
  source  = "tedilabs/network/aws//modules/subnet-group"
  version = "0.24.0"

  name                    = "${module.vpc.name}-private"
  vpc_id                  = module.vpc.id
  map_public_ip_on_launch = false

  subnets = {
    "${module.vpc.name}-private-001/az1" = {
      cidr_block           = "10.0.10.0/24"
      availability_zone_id = "apne2-az1"
    }
    "${module.vpc.name}-private-002/az2" = {
      cidr_block           = "10.0.11.0/24"
      availability_zone_id = "apne2-az2"
    }
  }

  tags = {}
}

module "route_table__public" {
  source  = "tedilabs/network/aws//modules/route-table"
  version = "0.24.0"

  name   = "${module.vpc.name}-public"
  vpc_id = module.vpc.id

  subnets = module.subnet_group__public.ids

  ipv4_routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.vpc.internet_gateway_id
    },
  ]

  tags = {}
}

module "route_table__private" {
  source  = "tedilabs/network/aws//modules/route-table"
  version = "0.24.0"

  name   = "${module.vpc.name}-private"
  vpc_id = module.vpc.id

  subnets = module.subnet_group__private.ids

  ipv4_routes = []

  tags = {}
}
