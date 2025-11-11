data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "web_test" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [module.web_test_sg.security_group_id]

  tags = {
    Name = "Learning Terraform_Test"
  }
}

module "web_test_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"
  name = "web_test_new"

  vpc_id = data.aws_vpc.default.id
  
  ingress_rules     = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules     = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}


resource "aws_security_group" "web_test" {
  name        = "web_test"
  description = "Allow http and https in. Allow Everything out"
  tags = {
    Terraform = "true"
  }
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "web_test_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_test.id
}


resource "aws_security_group_rule" "web_test_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_test.id
}


resource "aws_security_group_rule" "web_test_everything_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_test.id
}
