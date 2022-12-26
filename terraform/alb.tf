# Creating Application Load balancer and target group for Jenkins and App Ec2 instance access

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "${var.name}-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = ["${aws_security_group.allow-ingress-http.id}"]

  target_groups = [
    {
      name_prefix      = "jenk-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      targets = {
        jenk_target = {
          target_id = aws_instance.jenkins-ec2.private_ip
          port      = 8080
        }
      }
    },
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      targets = {
        app_target = {
          target_id = aws_instance.app-ec2.private_ip
          port      = 8080
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
      priority                = 1

      actions = [{
        type             = "forward"
        target_group_arn = module.alb.target_group_arns[0]
        protocol         = "HTTP"
      }]

      conditions = [{
        path_patterns = ["/jenkins", "/jenkins/*"]
      }]
    },
    {
      http_tcp_listener_index = 0
      priority                = 2

      actions = [{
        type             = "forward"
        target_group_arn = module.alb.target_group_arns[1]
        protocol         = "HTTP"
      }]

      conditions = [{
        path_patterns = ["/app", "/app/*"]
      }]
    }
  ]

  tags = {
    Name      = "${var.name}-alb"
    Terraform = "true"
  }
}