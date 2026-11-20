// Package cli implements the command-line entry point.
package cli

import (
	"fmt"
	"io"
)

const usage = `Usage:
  gh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--json]
  gh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]
  gh dependency-pulse --help
  gh dependency-pulse --version

Development skeleton: package checks and installation are not implemented yet.
`

// Run executes the CLI and returns its process exit code.
// Unsupported operations fail before any network access or process execution.
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 || (len(args) == 1 && (args[0] == "--help" || args[0] == "-h")) {
		if _, err := io.WriteString(stdout, usage); err != nil {
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "--version" {
		if _, err := fmt.Fprintln(stdout, "gh-dependency-pulse (development skeleton)"); err != nil {
			return 1
		}
		return 0
	}
	switch args[0] {
	case "check", "install":
		fmt.Fprintf(stderr, "%s is not implemented yet\n", args[0])
	default:
		io.WriteString(stderr, "unsupported command or arguments; use --help\n")
	}
	return 2
}
