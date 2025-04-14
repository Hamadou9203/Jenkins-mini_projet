terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.87.0"
    }
  }
}
provider "aws" {
  
  region                   = var.region
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY

}
terraform {
  backend "s3" {
    bucket = "terraform-backend-hamadou"
    key    = "terraform.tfstate"
    region = "us-east-1"
    

 
  }
}
data "aws_ami" "this" {
  most_recent = true
  owners      = ["099720109477"]

   filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  }

resource "aws_instance" "instance" {
  ami             = data.aws_ami.this.id
  instance_type   = var.type_instance
  key_name        = "Giltab-us"
  tags            = var.tags
  security_groups = [aws_security_group.allow_http_https_ssh.name]

   user_data = <<-EOF
   #!/bin/bash
   curl -fsSL https://get.docker.com -o install-docker.sh
   sh install-docker.sh --dry-run
   sudo sh install-docker.sh
   sudo usermod -aG docker ubuntu
  EOF
    
  provisioner "remote-exec" {

    inline = [
      "mkdir -p /app/data" 
    ]

  }
  provisioner "file" {
    source      = "/app/src/ressources/database/create.sql"
    destination = "/app/data/create.sql"
}
  connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key)  # Utiliser la variable Terraform pour la clé
      host        = self.public_ip
    }
}
resource "aws_security_group" "allow_http_https_ssh" {
  name = "jenkins-sg-14"

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
