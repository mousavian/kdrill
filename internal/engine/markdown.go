package engine

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// printMarkdown shows markdown text in the shell. When stdout is a terminal it
// pipes the text through `see` if that is installed, else through `mdv`; if
// neither is available, stdout is a pipe or file (they only render for a
// terminal), or the renderer fails, it prints the text as is.
func printMarkdown(md string) {
	md = strings.TrimSpace(md)
	if stdoutIsTerminal() && renderMarkdown(md) {
		return
	}
	fmt.Println(md)
}

// renderMarkdown renders md with the first available renderer and reports
// whether it succeeded. Renderers write straight to the terminal (they decide
// on width and colours from it).
func renderMarkdown(md string) bool {
	if p, err := exec.LookPath("see"); err == nil {
		cmd := exec.Command(p)
		cmd.Stdin = strings.NewReader(md)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		if cmd.Run() == nil {
			return true
		}
	}
	if p, err := exec.LookPath("mdv"); err == nil {
		// mdv reads a file, not stdin.
		f, err := os.CreateTemp("", "kdrill-*.md")
		if err != nil {
			return false
		}
		defer os.Remove(f.Name())
		_, werr := f.WriteString(md)
		f.Close()
		if werr != nil {
			return false
		}
		cmd := exec.Command(p, f.Name())
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		return cmd.Run() == nil
	}
	return false
}

func stdoutIsTerminal() bool {
	fi, err := os.Stdout.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}
