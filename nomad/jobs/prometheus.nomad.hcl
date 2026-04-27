job "prometheus" {
  datacenters = ["us-east-1"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" {
        static = 9090
      }
    }

    service {
      name = "prometheus"
      port = "http"

      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image        = "prom/prometheus:v2.53.0"
        network_mode = "host"
        ports        = ["http"]

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=7d",
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
          "--web.enable-lifecycle",
        ]

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
        ]
      }

      # Prometheus config rendered by Nomad template
      template {
        destination = "local/prometheus.yml"
        data        = <<-PROMCFG
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          scrape_configs:
            # ── Prometheus self-monitoring ──
            - job_name: "prometheus"
              static_configs:
                - targets: ["localhost:9090"]

            # ── Nomad servers & clients ──
            - job_name: "nomad"
              metrics_path: "/v1/metrics"
              params:
                format: ["prometheus"]
              consul_sd_configs:
                - server: "127.0.0.1:8500"
                  services: ["nomad", "nomad-client"]
              relabel_configs:
                - source_labels: [__meta_consul_service]
                  target_label: nomad_role

            # ── Consul agents ──
            - job_name: "consul"
              metrics_path: "/v1/agent/metrics"
              params:
                format: ["prometheus"]
              consul_sd_configs:
                - server: "127.0.0.1:8500"
                  services: ["consul"]
              relabel_configs:
                - source_labels: [__address__]
                  regex: "(.+):.*"
                  replacement: "$1:8500"
                  target_label: __address__
                - source_labels: [__meta_consul_node]
                  target_label: instance

            # ── Traefik ──
            - job_name: "traefik"
              metrics_path: "/metrics"
              consul_sd_configs:
                - server: "127.0.0.1:8500"
                  services: ["traefik"]
              relabel_configs:
                - source_labels: [__address__]
                  regex: "(.+):.*"
                  replacement: "$1:8081"
                  target_label: __address__

            # ── Node Exporter ──
            - job_name: "node-exporter"
              consul_sd_configs:
                - server: "127.0.0.1:8500"
                  services: ["node-exporter"]
        PROMCFG
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
