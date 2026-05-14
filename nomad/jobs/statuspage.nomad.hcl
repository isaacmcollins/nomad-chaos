job "statuspage" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "statuspage"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.statuspage.rule=PathPrefix(`/`)",
        "traefik.http.routers.statuspage.entrypoints=web",
      ]

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "raw_exec"

      config {
        command = "/usr/local/bin/statuspage"
      }

      env {
        NOMAD_REGION    = "${NOMAD_REGION}"
        NOMAD_DC        = "${NOMAD_DC}"
        NOMAD_NODE_NAME = "${node.unique.name}"
        NOMAD_ALLOC_ID  = "${NOMAD_ALLOC_ID}"
        APP_VERSION     = "1.0.0"
        PORT            = "${NOMAD_PORT_http}"
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}
