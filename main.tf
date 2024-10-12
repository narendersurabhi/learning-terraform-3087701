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


module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

/*
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  assign_ipv6_address_on_creation = "true"

  tags = {
    Name = "Main"
  }
}
*/

/*
resource "aws_launch_configuration" "blog_template" {
  name_prefix     = "aws-asg-"
  image_id        = data.aws_ami.app_ami.id
  instance_type   = var.instance_type  
  //user_data       = filebase64("user-data-2.sh")
  security_groups = [aws_security_group.sg_web.id] 

  lifecycle {
    create_before_destroy = true
  }
}
*/

resource "aws_launch_template" "blog_template" {
  name_prefix   = "aws-launch-template-"
  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  //user_data       = file("user-data.sh")


  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.sg_web.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on         = [aws_security_group.sg_web]  
}

resource "aws_autoscaling_group" "blog_asg" {
  //availability_zones = ["us-east-2a", "us-east-2b"]
  desired_capacity   = 2
  max_size           = 4
  min_size           = 2
  name = "blog"

  vpc_zone_identifier   = module.blog_vpc.public_subnets
  //security_groups = [aws_security_group.sg_web.id]   
  //launch_configuration = aws_launch_configuration.blog_template.name
  
  launch_template {
    id      = aws_launch_template.blog_template.id
    version = aws_launch_template.blog_template.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }  

  tag {
    key                 = "Environment"
    value               = "dev"
    propagate_at_launch = true
  }

  depends_on         = [aws_launch_template.blog_template, module.blog_vpc]  

}



resource "aws_lb" "blog_alb" {
  name               = "blog-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_lb.id]
  subnets            = module.blog_vpc.public_subnets
  depends_on         = [aws_security_group.sg_lb, module.blog_vpc]  
}

resource "aws_lb_target_group" "blog_tg" {
  name     = "blog-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id

  depends_on         = [module.blog_vpc]
}

resource "aws_autoscaling_attachment" "auto_to_targ" {
  autoscaling_group_name = aws_autoscaling_group.blog_asg.id
  //alb_target_group_arn   = aws_lb_target_group.blog_tg.arn
  lb_target_group_arn    = aws_lb_target_group.blog_tg.arn

  depends_on         = [aws_autoscaling_group.blog_asg, aws_lb_target_group.blog_tg]
}

resource "aws_security_group" "sg_lb" {
  name = "sg_lb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.blog_vpc.vpc_id

  depends_on         = [module.blog_vpc]
}

resource "aws_security_group" "sg_web" {
  name = "web-sg"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_lb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = module.blog_vpc.vpc_id

  depends_on         = [module.blog_vpc]
}


resource "aws_lb_listener" "blog_lb_lstnr" {
  load_balancer_arn = aws_lb.blog_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blog_tg.arn
  }

  depends_on         = [aws_lb.blog_alb, aws_lb_target_group.blog_tg]
}


/*
resource "aws_lb_target_group" "blog_tg" {
  name     = "blog-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}
*/

/*
resource "aws_lb_target_group" "blog_tg" {
  name     = "blog-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id

  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = "1"
      minimum_healthy_targets_percentage = "off"
    }

    unhealthy_state_routing {
      minimum_healthy_targets_count      = "1"
      minimum_healthy_targets_percentage = "off"
    }
  }
}
*/

/*
module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  # Security Group
  security_groups = [module.blog_lb_sg.security_group_id]

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
*/

/*
module "blog_lb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name = "blog_lb_sg"
  
  ingress_rules = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  vpc_id = module.blog_vpc.vpc_id
}

module "blog_as_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name = "blog_as_sg"
  
  ingress_rules = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = [module.blog_lb_sg.security_group_id]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  vpc_id = module.blog_vpc.vpc_id
}
*/

/*
resource "aws_launch_template" "foobar" {
  name_prefix   = "foobar"
  image_id      = "ami-1a2b3c"
  instance_type = "t2.micro"
}
*/