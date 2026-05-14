resource "aws_lb" "nomad" {
  name               = "nomad-chaos-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "nomad-chaos-alb"
  }
}

resource "aws_lb_target_group" "nomad_clients" {
  name     = "nomad-clients-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = {
    Name = "nomad-clients-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nomad.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad_clients.arn
  }
}
