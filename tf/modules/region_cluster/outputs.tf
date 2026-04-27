output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.nomad.dns_name
}

output "alb_arn" {
  value = aws_lb.nomad.arn
}

output "consul_server_asg_name" {
  value = aws_autoscaling_group.consul_server.name
}

output "nomad_server_asg_name" {
  value = aws_autoscaling_group.nomad_server.name
}

output "nomad_client_asg_name" {
  value = aws_autoscaling_group.nomad_client.name
}
