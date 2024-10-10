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


module "blog_asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.0"
  # insert the 1 required variable 
  
  name = "blog"
  min_size = 1
  max_size = 10

  vpc_zone_identifier  = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]
  
  image_id           = data.aws_ami.app_ami.id
  instance_type = var.instance_type  

  tags = {
    Environment = "dev"    
  }

}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  # Security Group
  security_groups = [module.blog_sg.security_group_id]

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

  target_groups = {
    ex-instance = {
      name_prefix      = "blog-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = module.blog_asg.autoscaling_group_id
    }
  }  

  tags = {
    Environment = "dev"    
  }
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["usw2-az1", "usw2-az2", "usw2-az3", "usw2-az4"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name = "blog_new"
  
  ingress_rules = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  vpc_id = module.blog_vpc.vpc_id
}
