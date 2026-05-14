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

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "route_table_id" {
  value = aws_route_table.public.id
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}
