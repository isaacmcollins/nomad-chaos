data "aws_ami" "cluster" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Project"
    values = [var.ami_project_tag]
  }
}

data "aws_region" "current" {}

# for auto join
resource "aws_iam_role" "cluster" {
  name = "nomad-chaos-cluster-${local.datacenter}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cloud_auto_join" {
  name = "consul-cloud-auto-join"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "cluster" {
  name = "nomad-chaos-cluster-${local.datacenter}"
  role = aws_iam_role.cluster.name
}

locals {
  datacenter             = data.aws_region.current.name
  consul_cloud_auto_join = ["provider=aws tag_key=ConsulCluster tag_value=${local.datacenter} region=${local.datacenter}"]
  consul_wan_join        = var.peer_datacenter != "" ? jsonencode(["provider=aws tag_key=Role tag_value=consul-server region=${var.peer_datacenter}"]) : jsonencode([])
  nomad_wan_join_list    = var.peer_datacenter != "" ? ["provider=aws tag_key=Role tag_value=nomad-server region=${var.peer_datacenter}"] : []
}

# =============================================================================
# Launch Templates
# =============================================================================

resource "aws_launch_template" "consul_server" {
  name_prefix   = "consul-server-"
  image_id      = data.aws_ami.cluster.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.cluster.name
  }

  vpc_security_group_ids = [aws_security_group.cluster.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/consul_server.sh.tftpl", {
    datacenter       = local.datacenter
    bootstrap_expect = var.consul_server_count
    retry_join       = jsonencode(local.consul_cloud_auto_join)
    retry_join_wan   = local.consul_wan_join
    ts_key           = var.tailscale_key
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Role          = "consul-server"
      ConsulCluster = local.datacenter
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "nomad_server" {
  name_prefix   = "nomad-server-"
  image_id      = data.aws_ami.cluster.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.cluster.name
  }

  vpc_security_group_ids = [aws_security_group.cluster.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/nomad_server.sh.tftpl", {
    datacenter        = local.datacenter
    bootstrap_expect  = var.nomad_server_count
    consul_retry_join = jsonencode(local.consul_cloud_auto_join)
    peer_datacenter   = var.peer_datacenter
    nomad_wan_join    = jsonencode(local.nomad_wan_join_list)
    ts_key            = var.tailscale_key
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Role          = "nomad-server"
      ConsulCluster = local.datacenter
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "nomad_client" {
  name_prefix   = "nomad-client-"
  image_id      = data.aws_ami.cluster.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.cluster.name
  }

  vpc_security_group_ids = [aws_security_group.cluster.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/nomad_client.sh.tftpl", {
    datacenter        = local.datacenter
    consul_retry_join = jsonencode(local.consul_cloud_auto_join)
    ts_key            = var.tailscale_key
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Role          = "nomad-client"
      ConsulCluster = local.datacenter
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Auto Scaling Groups
# =============================================================================

resource "aws_autoscaling_group" "consul_server" {
  name                = "consul-server-${local.datacenter}"
  desired_capacity    = var.consul_server_count
  min_size            = var.consul_server_count
  max_size            = var.consul_server_count
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.consul_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "consul-server-${local.datacenter}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ConsulCluster"
    value               = local.datacenter
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "consul-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nomad_server" {
  name                = "nomad-server-${local.datacenter}"
  desired_capacity    = var.nomad_server_count
  min_size            = var.nomad_server_count
  max_size            = var.nomad_server_count
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.nomad_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "nomad-server-${local.datacenter}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ConsulCluster"
    value               = local.datacenter
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "nomad-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nomad_client" {
  name                = "nomad-client-${local.datacenter}"
  desired_capacity    = var.nomad_client_count
  min_size            = var.nomad_client_count
  max_size            = var.nomad_client_count + 2
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.nomad_client.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.nomad_clients.arn]

  tag {
    key                 = "Name"
    value               = "nomad-client-${local.datacenter}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ConsulCluster"
    value               = local.datacenter
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "nomad-client"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

