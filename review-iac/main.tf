terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.87.0"
    }
  }
  required_version = "1.10.5"
}
provider "aws" {
  alias                    = "east"
  region                   = var.region
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY

}
data "aws_ami" "this" {
  most_recent = true
  owners      = ["099720109477"]

   filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  }

resource "aws_instance" "this" {
  ami             = data.aws_ami.this.id
  instance_type   = var.type_instance
  key_name        = "Giltab-us"
  tags            = var.tags
  security_groups = [aws_security_group.allow_http_https_ssh.name]

   user_data = <<EOF

   #!/bin/bash
   curl -fsSL https://get.docker.com -o install-docker.sh
   sh install-docker.sh --dry-run
   sudo sh install-docker.sh
   sudo usermod -aG docker ubuntu
   

    EOF
}
resource "aws_security_group" "allow_http_https_ssh" {
  name = "jenkins-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 8085
    to_port     = 8085
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
