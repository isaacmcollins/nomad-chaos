package cmd

import (
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/isaaccollins/nomad-chaos/chaos/pkg/grafana"
	"github.com/isaaccollins/nomad-chaos/chaos/pkg/nomad"
	"github.com/spf13/cobra"
)

func newGrafana() *grafana.Client {
	return grafana.NewClient(grafanaURL)
}

func annotateExperiment(name string) func() {
	gc := newGrafana()
	if err := gc.StartExperiment(name); err != nil {
		fmt.Printf("Warning: grafana annotation failed: %v\n", err)
	}
	return func() {
		if err := gc.EndExperiment(name); err != nil {
			fmt.Printf("Warning: grafana annotation failed: %v\n", err)
		}
	}
}

var runCmd = &cobra.Command{
	Use:   "run <experiment>",
	Short: "Run a chaos experiment",
	Long:  `Run a named chaos experiment against the cluster.`,
}

var appFailRequestRate int
var appFailRate int
var appFailDuration string

var appFailCmd = &cobra.Command{
	Use:   "app-fail",
	Short: "Inject HTTP failures into statuspage instances",
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Printf("Running app-fail: request-rate= %d rate=%d%% duration=%s\n", appFailRequestRate, appFailRate, appFailDuration)
		duration, err := time.ParseDuration(appFailDuration)
		if err != nil {
			return fmt.Errorf("invalid duration: %w", err)
		}

		defer annotateExperiment("app-fail")()

		params := url.Values{}
		params.Set("rate", strconv.Itoa(appFailRate))

		rate := time.Second / time.Duration(appFailRequestRate)
		ticker := time.NewTicker(rate)
		defer ticker.Stop()
		timeout := time.After(duration)

		for {
			select {
			case <-ticker.C:
				go func() {
					err := makeAppRequest(http.MethodGet, "/api/fail", params)
					if err != nil {
						fmt.Printf("error: %v\n", err)
					} else {
						fmt.Printf("recieved response\n")
					}

				}()
			case <-timeout:
				return nil
			}
		}
	},
}

var appSlowRate int
var appSlowDelay int
var appSlowDuration string

var appSlowCmd = &cobra.Command{
	Use:   "app-slow",
	Short: "Inject latency into statuspage instances",
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Printf("Running app-slow: rate=%d delay=%dms duration=%s\n", appSlowRate, appSlowDelay, appSlowDuration)

		duration, err := time.ParseDuration(appSlowDuration)
		if err != nil {
			return fmt.Errorf("invalid duration: %w", err)
		}

		defer annotateExperiment("app-slow")()

		params := url.Values{}
		params.Set("delay", strconv.Itoa(appSlowDelay))

		rate := time.Second / time.Duration(appSlowRate)
		ticker := time.NewTicker(rate)
		defer ticker.Stop()
		timeout := time.After(duration)

		for {
			select {
			case <-ticker.C:
				go func() {
					err := makeAppRequest(http.MethodGet, "/api/slow", params)
					if err != nil {
						fmt.Printf("error: %v\n", err)
					}
				}()
			case <-timeout:
				return nil
			}
		}
	},
}

var killAllocJob string
var killAllocCount int

var killAllocCmd = &cobra.Command{
	Use:   "kill-alloc",
	Short: "Kill Nomad allocations for a job",
	RunE: func(cmd *cobra.Command, args []string) error {
		defer annotateExperiment("kill-alloc")()
		return killAllocations(nomadAddr, killAllocJob, killAllocCount)
	},
}

var killLoopJob string
var killLoopInterval string
var killLoopDuration string

var killLoopCmd = &cobra.Command{
	Use:   "kill-loop",
	Short: "Repeatedly kill allocations on a schedule",
	RunE: func(cmd *cobra.Command, args []string) error {
		interval, err := time.ParseDuration(killLoopInterval)
		if err != nil {
			return fmt.Errorf("invalid interval: %w", err)
		}
		duration, err := time.ParseDuration(killLoopDuration)
		if err != nil {
			return fmt.Errorf("invalid duration: %w", err)
		}

		fmt.Printf("Running kill-loop: job=%s interval=%s duration=%s\n", killLoopJob, killLoopInterval, killLoopDuration)

		defer annotateExperiment("kill-loop")()

		if err := killAllocations(nomadAddr, killLoopJob, 1); err != nil {
			fmt.Printf("Warning: %v\n", err)
		}

		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		timeout := time.After(duration)

		for {
			select {
			case <-ticker.C:
				if err := killAllocations(nomadAddr, killLoopJob, 1); err != nil {
					fmt.Printf("Warning: %v\n", err)
				}
			case <-timeout:
				fmt.Println("Kill-loop duration reached, stopping.")
				return nil
			}
		}
	},
}

func killAllocations(nomadAddress, job string, count int) error {
	client, err := nomad.NewNomadClient(nomadAddress)
	if err != nil {
		return fmt.Errorf("failed to create nomad client: %w", err)
	}

	allocs, err := client.GetJobAllocations(job)
	if err != nil {
		return fmt.Errorf("failed to get allocations: %w", err)
	}
	if len(allocs) == 0 {
		return fmt.Errorf("no allocations found for %s", job)
	}

	for i := 0; i < count && i < len(allocs); i++ {
		if err := client.StopAllocation(allocs[i].ID); err != nil {
			return fmt.Errorf("failed to stop allocation %s: %w", allocs[i].ID, err)
		}
		fmt.Printf("Stopped allocation %s\n", allocs[i].ID)
	}
	return nil
}

func makeAppRequest(verb, route string, params url.Values) error {
	reqURL := strings.TrimRight(appURL, "/") + route
	if params != nil {
		reqURL = reqURL + "?" + params.Encode()
	}
	req, err := http.NewRequest(verb, reqURL, nil)
	if err != nil {
		return fmt.Errorf("building request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("making request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status: %s", resp.Status)
	}
	return nil
}

var loadRate int
var loadDuration string

var loadCmd = &cobra.Command{
	Use:   "load",
	Short: "Generate steady HTTP traffic against the app",
	RunE: func(cmd *cobra.Command, args []string) error {
		duration, err := time.ParseDuration(loadDuration)
		if err != nil {
			return fmt.Errorf("invalid duration: %w", err)
		}

		fmt.Printf("Running load: rate=%d req/s duration=%s target=%s\n", loadRate, loadDuration, appURL)

		interval := time.Second / time.Duration(loadRate)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		timeout := time.After(duration)

		var total, errors int64

		for {
			select {
			case <-ticker.C:
				go func() {
					err := makeAppRequest(http.MethodGet, "/api/health", nil)
					if err != nil {
						fmt.Printf("err: %v\n", err)
						errors++
					}
					total++
				}()
			case <-timeout:
				fmt.Printf("\nDone. total=%d errors=%d error_rate=%.1f%%\n", total, errors, float64(errors)/float64(max(total, 1))*100)
				return nil
			}
		}
	},
}

var spotNode string
var spotRandom bool

var spotTerminateCmd = &cobra.Command{
	Use:   "spot-terminate",
	Short: "Simulate spot instance termination via AWS API",
	Run: func(cmd *cobra.Command, args []string) {
		if spotRandom {
			fmt.Println("Running spot-terminate: random node")
		} else {
			fmt.Printf("Running spot-terminate: node=%s\n", spotNode)
		}
		// TODO: term some spot instances
	},
}

func init() {
	appFailCmd.Flags().IntVar(&appFailRequestRate, "request-rate", 10, "Requests per second")
	appFailCmd.Flags().IntVar(&appFailRate, "rate", 50, "Failure rate percentage")
	appFailCmd.Flags().StringVar(&appFailDuration, "duration", "60s", "Experiment duration")

	appSlowCmd.Flags().IntVar(&appSlowRate, "rate", 10, "Requests per second")
	appSlowCmd.Flags().IntVar(&appSlowDelay, "delay", 1000, "Injected delay in ms")
	appSlowCmd.Flags().StringVar(&appSlowDuration, "duration", "60s", "Experiment duration")

	killAllocCmd.Flags().StringVar(&killAllocJob, "job", "statuspage", "Nomad job name")
	killAllocCmd.Flags().IntVar(&killAllocCount, "count", 1, "Number of allocs to kill (or 'all')")

	killLoopCmd.Flags().StringVar(&killLoopJob, "job", "statuspage", "Nomad job name")
	killLoopCmd.Flags().StringVar(&killLoopInterval, "interval", "30s", "Kill interval")
	killLoopCmd.Flags().StringVar(&killLoopDuration, "duration", "5m", "Total duration")

	spotTerminateCmd.Flags().StringVar(&spotNode, "node", "", "Node name to terminate")
	spotTerminateCmd.Flags().BoolVar(&spotRandom, "random", false, "Terminate a random client node")

	loadCmd.Flags().IntVar(&loadRate, "rate", 50, "Requests per second")
	loadCmd.Flags().StringVar(&loadDuration, "duration", "5m", "Load duration")

	runCmd.AddCommand(appFailCmd, appSlowCmd, killAllocCmd, killLoopCmd, spotTerminateCmd, loadCmd)
	rootCmd.AddCommand(runCmd)
}
