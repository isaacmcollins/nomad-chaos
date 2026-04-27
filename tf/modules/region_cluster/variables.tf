variable "vpc_cidr" {
    type = string
}

variable "ami_project_tag" {
    type = string
    default = "nomad-chaos-demo"
}

variable "nomad_client_count" {
  type = number
  default = 1
}

variable "nomad_server_count" {
  type = number
  default = 1
}

variable "consul_server_count" {
  type = number
  default = 1
}

variable "tailscale_key" {
  type = string
  sensitive = true
}