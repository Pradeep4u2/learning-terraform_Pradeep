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

module "terra-test_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "terra-test" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [module.terra-test_sg.security_group_id]

  subnet_id = module.terra-test_vpc.public_subnets[0]

  tags = {
    Name = "Learning Terraform_Test"
  }
}

module "terra-test_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "terra-test-alb"
  vpc_id  = module.terra-test_vpc.vpc_id
  subnets = module.terra-test_vpc.public_subnets
  security_groups = [module.terra-test_sg.security_group_id]

  listeners = {
    ex-http-https-redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    ex-https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"

      forward = {
        target_group_key = "ex-instance"
      }
    }
  }

  target_groups = {
    ex-instance = {
      name_prefix      = "terra-test"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = "aws_instance.terra-test.id"
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "Example"
  }
}
module "terra-test_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"
  name = "terra-test"

  vpc_id = module.terra-test_vpc.vpc_id
  
  ingress_rules     = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules     = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
