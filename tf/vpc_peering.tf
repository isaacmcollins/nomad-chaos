resource "aws_vpc_peering_connection" "east_to_west" {
  provider    = aws.us_east_1
  vpc_id      = module.us_east_cluster.vpc_id
  peer_vpc_id = module.us_west_cluster.vpc_id
  peer_region = "us-west-2"

  tags = {
    Name = "nomad-chaos-east-west-peering"
    Side = "Requester"
  }
}

resource "aws_vpc_peering_connection_accepter" "west_accept" {
  provider                  = aws.us_west_2
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
  auto_accept               = true

  tags = {
    Name = "nomad-chaos-east-west-peering"
    Side = "Accepter"
  }
}

resource "aws_route" "east_to_west" {
  provider                  = aws.us_east_1
  route_table_id            = module.us_east_cluster.route_table_id
  destination_cidr_block    = module.us_west_cluster.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
}

resource "aws_route" "west_to_east" {
  provider                  = aws.us_west_2
  route_table_id            = module.us_west_cluster.route_table_id
  destination_cidr_block    = module.us_east_cluster.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
}

resource "aws_security_group_rule" "east_allow_west" {
  provider          = aws.us_east_1
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [module.us_west_cluster.vpc_cidr_block]
  security_group_id = module.us_east_cluster.cluster_security_group_id
  description       = "Allow all traffic from us-west-2 VPC peer"
}

resource "aws_security_group_rule" "west_allow_east" {
  provider          = aws.us_west_2
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [module.us_east_cluster.vpc_cidr_block]
  security_group_id = module.us_west_cluster.cluster_security_group_id
  description       = "Allow all traffic from us-east-1 VPC peer"
}
