resource "aws_globalaccelerator_accelerator" "nomad" {
  name            = "nomad-chaos"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled = false
  }
}

resource "aws_globalaccelerator_listener" "nomad_http" {
  accelerator_arn = aws_globalaccelerator_accelerator.nomad.id
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "nomad" {
  for_each = local.regional_clusters

  listener_arn          = aws_globalaccelerator_listener.nomad_http.id
  endpoint_group_region = each.key

  endpoint_configuration {
    endpoint_id                    = each.value.alb_arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}
