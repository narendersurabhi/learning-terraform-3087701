output "asg_target_group_arns" {
  value = module.blog_asg.autoscaling_group_target_group_arns
}

output "asg_arn" {
  value = module.blog_asg.autoscaling_group_arn
}

output "alb_dns_name" {
  value = module.blog_alb.dns_name
}
