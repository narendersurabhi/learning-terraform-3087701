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
  name = "blog_sg"
  
  ingress_rules = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  vpc_id = data.aws_vpc.default.id
}
