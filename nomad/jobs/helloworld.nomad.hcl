job "hello-world" {
  datacenters = ["us-east-1"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "hello-world"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hello.rule=PathPrefix(`/`)",
        "traefik.http.routers.hello.entrypoints=web"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "traefik/whoami:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}