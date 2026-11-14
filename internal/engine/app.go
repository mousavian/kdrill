// Package engine implements the kdrill commands.
package engine

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"kdrill/internal/state"
)

// exitError makes Run exit with a code without printing an error message.
type exitError struct{ code int }

func (e exitError) Error() string { return fmt.Sprintf("exit %d", e.code) }

// App holds configuration and loaded state for one invocation.
type App struct {
	Home, Cluster, StateDir string
	ctx                     context.Context
	st                      *state.State
}

const usage = `kdrill - hands-on Kubernetes practice lab

Setup
  doctor                       check docker, k3d, kubectl, memory
  cluster up|down|nuke|status  create/start, stop, delete, inspect the local cluster
  profile [lite|full]          show or set the resource profile

Courses
  courses                      list courses with progress
  lessons <course>             list lessons of a course
  course start|stop <course>   install / remove a course's components

Lesson loop (ref = <course>/<lesson>, e.g. k8s-scheduling/01)
  start <ref>                  set up a lesson
  show                         reprint the task
  status                       active lesson and cluster state
  hint                         reveal the next hint
  verify                       check your work (exit 0 on pass)
  reset                        cleanup, then start the lesson again
  solution                     show the reference solution
  cleanup                      remove the lesson's resources
  next                         clean up and start the next lesson

verify, reset, hint, cleanup, next, solution and show accept an optional <ref>;
all but solution/show fail if it is not the active lesson.

Environment: KDRILL_HOME, KDRILL_CLUSTER (default kdrill), KDRILL_STATE_DIR (default ~/.kdrill)
`

// Run executes a command line and returns the process exit code.
func Run(args []string, defaultHome string) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		fmt.Print(usage)
		return 0
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	a := &App{ctx: ctx, Cluster: envOr("KDRILL_CLUSTER", "kdrill")}
	a.StateDir = os.Getenv("KDRILL_STATE_DIR")
	if a.StateDir == "" {
		h, _ := os.UserHomeDir()
		a.StateDir = filepath.Join(h, ".kdrill")
	}
	err := a.dispatch(args[0], args[1:], defaultHome)
	if err == nil {
		return 0
	}
	var ee exitError
	if errors.As(err, &ee) {
		return ee.code
	}
	fmt.Fprintln(os.Stderr, "error: "+err.Error())
	return 1
}

func (a *App) dispatch(cmd string, args []string, defaultHome string) error {
	need := func(n int, u string) error {
		if len(args) != n {
			return fmt.Errorf("usage: kdrill %s", u)
		}
		return nil
	}
	opt := func(u string) (string, error) {
		if len(args) > 1 {
			return "", fmt.Errorf("usage: kdrill %s", u)
		}
		if len(args) == 1 {
			return args[0], nil
		}
		return "", nil
	}
	if cmd == "doctor" {
		return a.doctor()
	}
	home, err := resolveHome(defaultHome)
	if err != nil {
		return err
	}
	a.Home = home
	if a.st, err = state.Load(a.statePath()); err != nil {
		return fmt.Errorf("reading %s: %w", a.statePath(), err)
	}
	switch cmd {
	case "cluster":
		if len(args) != 1 {
			return fmt.Errorf("usage: kdrill cluster up|down|nuke|status")
		}
		return a.clusterCmd(args[0])
	case "courses":
		return a.courses()
	case "lessons":
		if err := need(1, "lessons <course>"); err != nil {
			return err
		}
		return a.lessons(args[0])
	case "course":
		if len(args) != 2 || (args[0] != "start" && args[0] != "stop") {
			return fmt.Errorf("usage: kdrill course start|stop <course>")
		}
		return a.courseCmd(args[0], args[1])
	case "start":
		if err := need(1, "start <course>/<lesson>"); err != nil {
			return err
		}
		return a.startRef(args[0])
	case "status":
		return a.status()
	case "profile":
		p, err := opt("profile [lite|full]")
		if err != nil {
			return err
		}
		return a.profile(p)
	case "show", "solution":
		ref, err := opt(cmd + " [<course>/<lesson>]")
		if err != nil {
			return err
		}
		if cmd == "show" {
			return a.show(ref)
		}
		return a.solution(ref)
	case "hint", "verify", "reset", "cleanup", "next":
		ref, err := opt(cmd + " [<course>/<lesson>]")
		if err != nil {
			return err
		}
		return a.activeCmd(cmd, ref)
	}
	return fmt.Errorf("unknown command %q (try: kdrill help)", cmd)
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func (a *App) statePath() string      { return filepath.Join(a.StateDir, "state.json") }
func (a *App) kubeconfigPath() string { return filepath.Join(a.StateDir, "kubeconfig") }
func (a *App) save() error            { return a.st.Save(a.statePath()) }

func validHome(d string) bool {
	for _, sub := range []string{"base", "courses"} {
		if fi, err := os.Stat(filepath.Join(d, sub)); err != nil || !fi.IsDir() {
			return false
		}
	}
	return true
}

func walkUp(dir string) string {
	for {
		if validHome(dir) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

// resolveHome finds the repo root: $KDRILL_HOME, build-time default, cwd, executable dir.
func resolveHome(defaultHome string) (string, error) {
	if h := os.Getenv("KDRILL_HOME"); h != "" {
		if !validHome(h) {
			return "", fmt.Errorf("KDRILL_HOME=%s has no base/ and courses/ directories", h)
		}
		return h, nil
	}
	if defaultHome != "" && validHome(defaultHome) {
		return defaultHome, nil
	}
	if wd, err := os.Getwd(); err == nil {
		if h := walkUp(wd); h != "" {
			return h, nil
		}
	}
	if exe, err := os.Executable(); err == nil {
		if r, err := filepath.EvalSymlinks(exe); err == nil {
			exe = r
		}
		if h := walkUp(filepath.Dir(exe)); h != "" {
			return h, nil
		}
	}
	return "", fmt.Errorf("cannot find the kdrill repo (a directory with base/ and courses/); set KDRILL_HOME")
}

// ---------------------------------------------------------------- exec ----

// run executes a command and returns trimmed stdout; stderr is folded into the error.
func run(cmd *exec.Cmd) (string, error) {
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(errb.String())
		if msg == "" {
			msg = strings.TrimSpace(out.String())
		}
		if msg == "" {
			return "", fmt.Errorf("%s: %w", cmd.Args[0], err)
		}
		return "", fmt.Errorf("%s: %s", cmd.Args[0], msg)
	}
	return strings.TrimSpace(out.String()), nil
}

// kubectl builds a kubectl command pinned to the dedicated kubeconfig.
func (a *App) kubectl(args ...string) *exec.Cmd {
	cmd := exec.CommandContext(a.ctx, "kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+a.kubeconfigPath())
	return cmd
}

func (a *App) k(args ...string) (string, error) { return run(a.kubectl(args...)) }

// runScript runs a script the way hack/lesson.sh does: common.sh is sourced first.
// extra holds KDRILL_* variables; dir is the working directory.
func (a *App) runScript(script, dir, phase string, extra []string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(a.ctx, timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "bash", "-c",
		`source "$KDRILL_HOME/base/lib/common.sh"; source "$1"`, "_", script)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"KUBECONFIG="+a.kubeconfigPath(),
		"KDRILL_HOME="+a.Home,
		"KDRILL_PHASE="+phase,
		"KDRILL_PROFILE="+a.st.Profile)
	cmd.Env = append(cmd.Env, extra...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = nil, os.Stdout, os.Stderr
	// Own process group so a timeout or Ctrl-C also kills kubectl children.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 3 * time.Second
	err := cmd.Run()
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return fmt.Errorf("%s timed out after %s", filepath.Base(script), timeout)
	}
	if a.ctx.Err() != nil {
		return fmt.Errorf("interrupted")
	}
	return err
}

func fileExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && !fi.IsDir()
}
