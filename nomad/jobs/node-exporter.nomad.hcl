job "node-exporter" {
  datacenters = ["dc1"]
  type        = "system"

  group "node-exporter" {
    network {
      port "metrics" {
        static = 9100
      }
    }

    service {
      name = "node-exporter"
      port = "metrics"

      check {
        type     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image        = "prom/node-exporter:v1.8.1"
        network_mode = "host"
        ports        = ["metrics"]

        args = [
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_metrics}",
          "--path.procfs=/host/proc",
          "--path.sysfs=/host/sys",
          "--path.rootfs=/host/root",
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)",
        ]

        volumes = [
          "/proc:/host/proc:ro",
          "/sys:/host/sys:ro",
          "/:/host/root:ro",
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
