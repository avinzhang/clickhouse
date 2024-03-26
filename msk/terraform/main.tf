terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-southeast-2"
}
resource "aws_vpc" "msk-cluster" {
  cidr_block = "192.168.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    "Name"        = "avin-msk-vpc"
  }
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.azs.names[0]
  cidr_block        = "192.168.0.0/24"
  vpc_id            = aws_vpc.msk-cluster.id
  tags = {
    "Name"        = "msk-subnet-1"
  }
}

resource "aws_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.azs.names[1]
  cidr_block        = "192.168.1.0/24"
  vpc_id            = aws_vpc.msk-cluster.id
  tags = {
    "Name"        = "msk-subnet-2"
  }
}

resource "aws_subnet" "subnet_az3" {
  availability_zone = data.aws_availability_zones.azs.names[2]
  cidr_block        = "192.168.2.0/24"
  vpc_id            = aws_vpc.msk-cluster.id
  tags = {
    "Name"        = "msk-subnet-3"
  }
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.msk-cluster.id
  name   = "msk-kafka"
  ingress {
    from_port   = 9096
    to_port     = 9096
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9092
    to_port     = 9092
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

resource "aws_internet_gateway" "msk_ig" {
  vpc_id = aws_vpc.msk-cluster.id
  tags = {
    "Name"        = "msk-internet-gateway"
  }
}

resource "aws_route" "to_internet_gateway" {
  route_table_id         = aws_vpc.msk-cluster.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.msk_ig.id
}

resource "aws_kms_key" "kms" {
  description = "example"
}

resource "aws_msk_configuration" "kafka_config" {
  name = "msk-config"
  server_properties = <<EOF
auto.create.topics.enable = true
delete.topic.enable = true
allow.everyone.if.no.acl.found = false
EOF
}

# Creates a provisioned MSK cluster
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name           = "avin-msk-cluster"
  kafka_version          = "3.4.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    az_distribution = "DEFAULT"
    client_subnets  = [
      aws_subnet.subnet_az1.id,
      aws_subnet.subnet_az2.id,
      aws_subnet.subnet_az3.id,
    ]
    connectivity_info {
      public_access {
        #type = "DISABLED"
        type = "SERVICE_PROVIDED_EIPS"
      }
    }
    instance_type   = "kafka.m5.large"
    security_groups = [aws_security_group.sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 100
        provisioned_throughput {
          enabled = false
        }
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
    encryption_at_rest_kms_key_arn = aws_kms_key.kms.arn
  }
  configuration_info {
    arn = aws_msk_configuration.kafka_config.arn
    revision = aws_msk_configuration.kafka_config.latest_revision
  }


  client_authentication {
    sasl {
      scram = true
    }
  }

  tags = {
    "Name"        = "avin-msk-cluster"
  }
}

resource "aws_secretsmanager_secret" "msk-secret" {
  name       = "AmazonMSK_logins"
  kms_key_id = aws_kms_key.kms.key_id
}

resource "aws_msk_scram_secret_association" "msk-secret-association" {
  cluster_arn     = aws_msk_cluster.msk_cluster.arn
  secret_arn_list = [aws_secretsmanager_secret.msk-secret.arn]

  depends_on = [aws_secretsmanager_secret_version.msk-secret-version]
}

resource "aws_secretsmanager_secret_version" "msk-secret-version" {
  secret_id     = aws_secretsmanager_secret.msk-secret.id
  secret_string = jsonencode({ username = "user", password = "password" })
}

data "aws_iam_policy_document" "example" {
  statement {
    sid    = "AWSKafkaResourcePolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }

    actions   = ["secretsmanager:getSecretValue"]
    resources = [aws_secretsmanager_secret.msk-secret.arn]
  }
}

resource "aws_secretsmanager_secret_policy" "example" {
  secret_arn = aws_secretsmanager_secret.msk-secret.arn
  policy     = data.aws_iam_policy_document.example.json
}


output "bootstrap_brokers_sasl_scram" {
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_public_sasl_scram
  description = "sasl_scram connection string (host:port pairs)"
}

