package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"math/rand/v2"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	startTime    = time.Now()
	requestCount atomic.Int64

	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "statuspage_http_requests_total",
		Help: "Total requests per route and HTTP status code",
	}, []string{"path", "status"})

	httpDurationSeconds = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "statuspage_http_duration_seconds",
		Help: "Request latency per route",
	}, []string{"path"})

	info = Info{
		Port:       envOrDefault("PORT", "8080"),
		Region:     envOrDefault("NOMAD_REGION", "unknown"),
		Datacenter: envOrDefault("NOMAD_DC", "unknown"),
		NodeName:   envOrDefault("NOMAD_NODE_NAME", "unknown"),
		AllocID:    envOrDefault("NOMAD_ALLOC_ID", "unknown"),
		Version:    envOrDefault("APP_VERSION", "unknown"),
	}
)

type Info struct {
	Port       string `json:"port,omitempty"`
	Region     string `json:"region"`
	Datacenter string `json:"datacenter"`
	NodeName   string `json:"node_name"`
	AllocID    string `json:"alloc_id"`
	Version    string `json:"version"`
	Uptime     string `json:"uptime"`
	Requests   int64  `json:"requests"`
}

type templateData struct {
	Info
	Uptime   string
	Requests int64
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (sw *statusWriter) WriteHeader(code int) {
	sw.status = code
	sw.ResponseWriter.WriteHeader(code)
}

func instrument(path string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		requestCount.Add(1)
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()
		next(sw, r)
		duration := time.Since(start).Seconds()
		httpDurationSeconds.WithLabelValues(path).Observe(duration)
		httpRequestsTotal.WithLabelValues(path, strconv.Itoa(sw.status)).Inc()
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	data := templateData{
		Info:     info,
		Uptime:   time.Since(startTime).Round(time.Second).String(),
		Requests: requestCount.Load(),
	}
	indexTmpl.Execute(w, data)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	resp := info
	resp.Uptime = time.Since(startTime).Round(time.Second).String()
	resp.Requests = requestCount.Load()
	json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("ok"))
}

func slowHandler(w http.ResponseWriter, r *http.Request) {
	delayMs, err := strconv.Atoi(r.URL.Query().Get("delay"))
	if err != nil {
		delayMs = 500
	}
	time.Sleep(time.Duration(delayMs) * time.Millisecond)
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "responded after %dms", delayMs)
}

func failHandler(w http.ResponseWriter, r *http.Request) {
	rate, err := strconv.Atoi(r.URL.Query().Get("rate"))
	if err != nil {
		rate = 50
	}
	if rand.IntN(100) < rate {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("simulated failure"))
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func envOrDefault(k, defaultVal string) string {
	if v, ok := os.LookupEnv(k); ok {
		return v
	}
	return defaultVal
}

func main() {
	fmt.Println("Starting on port " + info.Port)

	http.HandleFunc("/", instrument("/", handleIndex))
	http.HandleFunc("/api/info", instrument("/api/info", infoHandler))
	http.HandleFunc("/api/health", instrument("/api/health", healthHandler))
	http.HandleFunc("/api/slow", instrument("/api/slow", slowHandler))
	http.HandleFunc("/api/fail", instrument("/api/fail", failHandler))
	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":"+info.Port, nil)
}

var indexTmpl = template.Must(template.New("index").Parse(`<!DOCTYPE html>
<html>
<head>
  <title>statuspage</title>
  <style>
    body { font-family: monospace; max-width: 600px; margin: 60px auto; background: #0d1117; color: #c9d1d9; }
    h1 { color: #58a6ff; }
    table { border-collapse: collapse; width: 100%; }
    td { padding: 6px 12px; border-bottom: 1px solid #21262d; }
    td:first-child { color: #8b949e; }
    .tag { display: inline-block; background: #1f6feb33; color: #58a6ff; padding: 2px 8px; border-radius: 4px; font-size: 0.85em; }
  </style>
</head>
<body>
  <h1>statuspage</h1>
  <table>
    <tr><td>Region</td><td><span class="tag">{{.Region}}</span></td></tr>
    <tr><td>Datacenter</td><td><span class="tag">{{.Datacenter}}</span></td></tr>
    <tr><td>Node</td><td>{{.NodeName}}</td></tr>
    <tr><td>Alloc</td><td><code>{{.AllocID}}</code></td></tr>
    <tr><td>Version</td><td>{{.Version}}</td></tr>
    <tr><td>Uptime</td><td>{{.Uptime}}</td></tr>
    <tr><td>Requests</td><td>{{.Requests}}</td></tr>
  </table>
  <p style="margin-top:2em;color:#484f58;font-size:0.8em">
    <a href="/api/info" style="color:#58a6ff">/api/info</a>
    <a href="/api/health" style="color:#58a6ff">/api/health</a>
    <a href="/metrics" style="color:#58a6ff">/metrics</a>
  </p>
</body>
</html>`))
