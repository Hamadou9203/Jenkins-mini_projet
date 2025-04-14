variable "region" {
  type = string
  default = "us-east-1"
}


variable "type_instance" {
  type    = string
  default = "t2.micro"

}

variable "tags" {
  type        = map(any)
  description = "value tag"
  default = {
    Name = "ec2-review"
  }

}
variable "AWS_ACCESS_KEY" {  
  type = string
  default = ""
}
variable "AWS_SECRET_KEY" {  
  type = string
  default = ""
}
variable "ssh_key" {
  type = string
  description = "Private SSH key"
}
