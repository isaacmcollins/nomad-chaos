job "nomad-app" {
  datacenters = ["us-east-1"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "nomad-app"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nomad-app.rule=PathPrefix(`/`)",
        "traefik.http.routers.nomad-app.entrypoints=web",
      ]

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "docker.io/isaaccollins/nomad-app:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
