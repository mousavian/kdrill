// kdrill: a local hands-on Kubernetes practice lab.
package main

import (
	"os"

	"kdrill/internal/engine"
)

// defaultHome is injected at build time: -ldflags "-X main.defaultHome=/path/to/kdrill".
var defaultHome string

func main() {
	os.Exit(engine.Run(os.Args[1:], defaultHome))
}
