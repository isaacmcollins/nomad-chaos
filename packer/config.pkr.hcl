packer {
  required_plugins {
    amazon = {
      version = ">= 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "regions" {
  type    = list(string)
  default = ["us-east-1"]
}

source "amazon-ebs" "nomad_consul_base" {
  region        = var.regions[0]
  instance_type = "t3.micro"
  ssh_username  = "ubuntu"
  ami_name      = "nomad-consul-golden-image-{{timestamp}}"
  ami_regions   = var.regions

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  tags = {
    Project     = "nomad-chaos-demo"
    Environment = "portfolio-lab"
    OS_Version  = "Ubuntu-22.04"
  }
}

build {
  sources = ["source.amazon-ebs.nomad_consul_base"]

  provisioner "file" {
    source      = "../app"
    destination = "/tmp/app"
  }

  provisioner "shell" {
    script = "./scripts/install.sh"
  }
}