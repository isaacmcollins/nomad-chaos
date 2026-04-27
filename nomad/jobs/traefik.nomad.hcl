job "traefik" {
  datacenters = ["us-east-1"]
  type        = "system"

  group "traefik" {
    network {
      port "web" {
        static = 8080
      }
      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"
      port = "web"
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.10"
        network_mode = "host"
        
        args = [
          "--api.insecure=true",
          "--accesslog=true",
          "--metrics.prometheus=true",
          
          # Entrypoints
          "--entrypoints.web.address=:${NOMAD_PORT_web}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_api}",
          
          # Consul Catalog Provider configuration
          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint.address=127.0.0.1:8500",
          "--providers.consulcatalog.exposedByDefault=false"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}