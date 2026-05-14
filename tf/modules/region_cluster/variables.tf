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
  type      = string
  sensitive = true
}

variable "peer_datacenter" {
  type        = string
  default     = ""
  description = "Region name of the peer datacenter to federate with (e.g. us-west-2). Leave empty to skip federation."
}