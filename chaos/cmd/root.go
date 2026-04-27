package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var (
	nomadAddr  string
	consulAddr string
	grafanaURL string
	appURL     string
)

var rootCmd = &cobra.Command{
	Use:   "chaos",
	Short: "Chaos engineering CLI for Nomad clusters",
	Long:  `A CLI tool that runs chaos experiments against a Nomad cluster and annotates Grafana dashboards.`,
}

func Execute() error {
	return rootCmd.Execute()
}
func init() {

	rootCmd.PersistentFlags().StringVar(&nomadAddr, "nomad-addr", envOrDefault("NOMAD_ADDR", "http://127.0.0.1:4646"), "Nomad API address")
	rootCmd.PersistentFlags().StringVar(&consulAddr, "consul-addr", envOrDefault("CONSUL_ADDR", "http://127.0.0.1:8500"), "Consul API address")
	rootCmd.PersistentFlags().StringVar(&grafanaURL, "grafana-url", envOrDefault("GRAFANA_URL", "http://127.0.0.1:3000"), "Grafana URL for annotations")
	rootCmd.PersistentFlags().StringVar(&appURL, "app-url", envOrDefault("APP_URL", "http://localhost:8080"), "Test application URL")
}

func envOrDefault(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}
