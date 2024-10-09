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

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  tags = {
    Name = "HelloWorld"
  }

  vpc_security_group_ids = [module.security_group_module.security_group_id]
}

data "aws_vpc" "default" {
  default = true
}

module "security_group_module" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name = "blog_module_sg"
  
  ingress_rules = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "blog" {
  vpc_id = data.aws_vpc.default.id
  name   = "blog"
  tags   = {
    Terraform = "true"
  }
}

resource "aws_security_group_rule" "blog_http_in" {
  security_group_id = aws_security_group.blog.id

  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "blog_https_in" {
  security_group_id = aws_security_group.blog.id

  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "blog_all_out" {
  security_group_id = aws_security_group.blog.id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
