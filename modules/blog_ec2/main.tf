module "blog_ec2" {
  source = "./modules/blog_ec2"

  count = var.instance_count
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = element(module.blog_vpc.public_subnets, count.index)
  security_groups = [module.blog_sg.security_group_id]
}

output "instance_ids" {
  value = aws_instance.blog[*].id
}
