terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    clickhouse = {
      version = "0.0.5"
      source  = "ClickHouse/clickhouse"
    }
  }
  required_version = ">= 1.2.0"
}


provider "aws" {
  region  = "ap-southeast-2"
}


data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  region = "ap-southeast-2"
  availability_zones = sort(data.aws_availability_zones.available.names)
}


resource "aws_vpc" "myvpc" {
  cidr_block = "192.168.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    "Name"        = "${name}-vpc"
  }
}



data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "sn_az" {
  count = length(local.availability_zones)

  availability_zone = local.availability_zones[count.index]

  vpc_id = aws_vpc.myvpc.id
  map_public_ip_on_launch = true

  cidr_block = cidrsubnet(aws_vpc.myvpc.cidr_block, 5, count.index+1)

  tags = {
    Name = "${name}-subnet-${count.index + 1}"
  }
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.myvpc.id
  name   = "${name}-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9440
    to_port     = 9440
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "avin_ig" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    "Name"        = "${name}-internet-gateway"
  }
}

resource "aws_route" "to_internet_gateway" {
  route_table_id         = aws_vpc.myvpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.avin_ig.id
}

resource "aws_key_pair" "keypair" {
  key_name   = "${name}-tf-sshkey"
  public_key = file("/Users/avin/.ssh/id_rsa.pub")
}


resource "aws_instance" "instance" {
  count = 1
  ami = "ami-09b42976632b27e9b"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.keypair.key_name}"
  associate_public_ip_address = true
  subnet_id = element(aws_subnet.sn_az.*.id, count.index)
  vpc_security_group_ids      = [aws_security_group.sg.id]

  tags = {
    Name = "${name}-terraform-${count.index + 1}"
  }
}

output "ec2-ip" {
  value = "${aws_instance.instance[0].public_ip}"
}

variable "clickhouse_pl_svc_name" {
  type = string
}


resource "aws_vpc_endpoint" "pl_endpoint" {
  vpc_id            = aws_vpc.myvpc.id
  service_name      = var.clickhouse_pl_svc_name
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    aws_security_group.sg.id
  ]
  subnet_ids          = "${aws_subnet.sn_az[*].id}"
  private_dns_enabled = true
}

output "vpce_id" {
  value = "${aws_vpc_endpoint.pl_endpoint.id} - Add to Clickhouse service Access List"
}


variable "token_key" {
  type = string
}

variable "token_secret" {
  type = string
}

variable "organization_id" {
  type = string
}

provider "clickhouse" {
  organization_id = var.organization_id
  token_key       = var.token_key
  token_secret    = var.token_secret
}

resource "clickhouse_private_endpoint_registration" "private_endpoint_aws" {
  cloud_provider = "aws"
  region = "ap-southeast-2"
  id             = aws_vpc_endpoint.pl_endpoint.id
  description    = "Private Link from VPC"
}

