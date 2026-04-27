package main

import (
	"os"

	"github.com/isaaccollins/nomad-chaos/chaos/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
