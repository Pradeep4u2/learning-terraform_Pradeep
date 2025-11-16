
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets = [
    "${var.environment.network_prefix}.0.1/24",
    "${var.environment.network_prefix}.0.2/24",
    "${var.environment.network_prefix}.0.3/24"
  ]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}


module "blog_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.0.2"

  name = "${var.environment.name}-blog"

  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.blog_sg.security_group_id]

  instance_type = var.instance_type
  image_id      = data.aws_ami.app_ami.id

}


module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.2.0" # upgrade from 8.4.0

  name               = "${var.environment.name}-blog-alb"
  load_balancer_type = "application"
  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = [module.blog_sg.security_group_id]


target_groups = {
  blog_tg = {
    name_prefix = "blog"
    port        = 80
    protocol    = "HTTP"
    target_type = "instance"
    create_attachment = false  # <--- disable built-in attachments
  }
}

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
}
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = module.blog_autoscaling.autoscaling_group_name
  lb_target_group_arn    = module.blog_alb.target_groups["blog_tg"].arn
}

# ALB Outputs
output "alb_dns_name" {
  value = module.blog_alb.dns_name
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id  = module.blog_vpc.vpc_id
  name    = "${var.environment.name}-blog"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
