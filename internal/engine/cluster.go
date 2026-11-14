package engine

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"kdrill/internal/state"
)

type k3dCluster struct {
	Name           string `json:"name"`
	ServersCount   int    `json:"serversCount"`
	ServersRunning int    `json:"serversRunning"`
}

// clusterState reports whether the k3d cluster exists and is running.
func (a *App) clusterState() (exists, running bool, err error) {
	out, err := run(exec.CommandContext(a.ctx, "k3d", "cluster", "list", "-o", "json"))
	if err != nil {
		return false, false, err
	}
	var list []k3dCluster
	if err := json.Unmarshal([]byte(out), &list); err != nil {
		return false, false, fmt.Errorf("parsing k3d output: %w", err)
	}
	for _, c := range list {
		if c.Name == a.Cluster {
			return true, c.ServersRunning > 0, nil
		}
	}
	return false, false, nil
}

func (a *App) requireCluster() error {
	exists, running, err := a.clusterState()
	if err != nil {
		return fmt.Errorf("%w\n  is k3d installed and Docker running? try: kdrill doctor", err)
	}
	if !exists || !running {
		return fmt.Errorf("cluster %q is not running; run: kdrill cluster up", a.Cluster)
	}
	if !fileExists(a.kubeconfigPath()) {
		return a.writeKubeconfig()
	}
	return nil
}

func (a *App) writeKubeconfig() error {
	out, err := run(exec.CommandContext(a.ctx, "k3d", "kubeconfig", "get", a.Cluster))
	if err != nil {
		return err
	}
	if err := os.MkdirAll(a.StateDir, 0o755); err != nil {
		return err
	}
	p := a.kubeconfigPath()
	if err := os.WriteFile(p, []byte(out+"\n"), 0o600); err != nil {
		return err
	}
	return os.Chmod(p, 0o600)
}

func stream(a *App, name string, args ...string) error {
	cmd := exec.CommandContext(a.ctx, name, args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func (a *App) clusterCmd(sub string) error {
	switch sub {
	case "up":
		return a.clusterUp()
	case "down":
		exists, running, err := a.clusterState()
		if err != nil {
			return err
		}
		if !exists || !running {
			fmt.Printf("cluster %s is not running\n", a.Cluster)
			return nil
		}
		if err := stream(a, "k3d", "cluster", "stop", a.Cluster); err != nil {
			return err
		}
		fmt.Println("cluster stopped (lesson state is kept; resume with: kdrill cluster up)")
		return nil
	case "nuke":
		if exists, _, err := a.clusterState(); err != nil {
			return err
		} else if exists {
			if err := stream(a, "k3d", "cluster", "delete", a.Cluster); err != nil {
				return err
			}
		}
		a.st.Active, a.st.Components, a.st.Courses = nil, nil, nil
		if err := a.save(); err != nil {
			return err
		}
		fmt.Println("cluster deleted; progress kept. Create a new one with: kdrill cluster up")
		return nil
	case "status":
		return a.clusterStatus()
	}
	return fmt.Errorf("usage: kdrill cluster up|down|nuke|status")
}

func (a *App) clusterUp() error {
	exists, running, err := a.clusterState()
	if err != nil {
		return err
	}
	restarted := false
	switch {
	case !exists:
		fmt.Printf("creating k3d cluster %s (first run pulls images, ~1-2 min)...\n", a.Cluster)
		err = stream(a, "k3d", "cluster", "create", a.Cluster,
			"--servers", "1", "--agents", "0", "--no-lb",
			"--k3s-arg", "--disable=traefik@server:0",
			"--k3s-arg", "--disable=servicelb@server:0",
			"--k3s-arg", "--disable=metrics-server@server:0",
			"--wait", "--timeout", "180s")
		// A brand-new cluster has nothing installed.
		a.st.Active, a.st.Components, a.st.Courses = nil, nil, nil
	case !running:
		restarted = true
		fmt.Printf("starting k3d cluster %s...\n", a.Cluster)
		err = stream(a, "k3d", "cluster", "start", a.Cluster, "--wait", "--timeout", "180s")
	default:
		fmt.Printf("cluster %s is already running\n", a.Cluster)
	}
	if err != nil {
		return err
	}
	if err := a.writeKubeconfig(); err != nil {
		return err
	}
	fmt.Println("waiting for the node to be Ready...")
	if _, err := a.k("wait", "node", "-l", "!type", "--for=condition=Ready", "--timeout=120s"); err != nil {
		return err
	}
	// System pods must be able to come back after a restart, so lift the sim
	// taint while they start, then restore it if a sim lesson is active.
	a.setSimTaint(false)
	if _, err := a.k("-n", "kube-system", "wait", "deploy", "--all", "--for=condition=Available", "--timeout=180s"); err != nil {
		return err
	}
	if err := a.installComponent("kwok"); err != nil {
		return err
	}
	if restarted {
		// KWOK can stop managing fake pods after the cluster restarts.
		a.k("-n", "kube-system", "rollout", "restart", "deploy/kwok-controller")
		a.k("-n", "kube-system", "rollout", "status", "deploy/kwok-controller", "--timeout=120s")
	}
	if a.st.Active != nil {
		if lc, err := a.loadActive(); err == nil {
			a.setSimTaint(lc.lesson().EffectiveKind(lc.c) == "sim")
		}
	}
	if err := a.save(); err != nil {
		return err
	}
	fmt.Printf("\ncluster %s is ready. Next:\n  kdrill start k8s-scheduling/01\n", a.Cluster)
	return nil
}

func (a *App) clusterStatus() error {
	exists, running, err := a.clusterState()
	if err != nil {
		return err
	}
	switch {
	case !exists:
		fmt.Printf("cluster %s: does not exist (kdrill cluster up)\n", a.Cluster)
	case !running:
		fmt.Printf("cluster %s: stopped (kdrill cluster up)\n", a.Cluster)
	default:
		fmt.Printf("cluster %s: running\n", a.Cluster)
		if fileExists(a.kubeconfigPath()) {
			if out, err := a.k("get", "nodes", "--no-headers"); err == nil {
				for _, l := range strings.Split(out, "\n") {
					fmt.Println("  " + l)
				}
			}
		}
	}
	if len(a.st.Components) > 0 {
		fmt.Println("components: " + strings.Join(a.st.Components, ", "))
	}
	return nil
}

// ---------------------------------------------------------------- doctor ----

func (a *App) doctor() error {
	bad := 0
	row := func(ok bool, warnOnly bool, msg, fix string) {
		switch {
		case ok:
			fmt.Printf("✓ %s\n", msg)
		case warnOnly:
			fmt.Printf("! %s\n    fix: %s\n", msg, fix)
		default:
			bad++
			fmt.Printf("✗ %s\n    fix: %s\n", msg, fix)
		}
	}
	dockerOK := false
	if out, err := run(exec.CommandContext(a.ctx, "docker", "info", "--format", "{{.MemTotal}}")); err != nil {
		row(false, false, "docker daemon not reachable", "start Docker Desktop (or OrbStack/Colima) and retry")
	} else {
		dockerOK = true
		row(true, false, "docker daemon reachable", "")
		b, _ := strconv.ParseFloat(out, 64)
		gb := b / (1 << 30)
		row(gb >= 3, true, fmt.Sprintf("docker VM memory %.1f GB", gb),
			"raise it to at least 3-4 GB (Docker Desktop > Settings > Resources)")
	}
	for _, t := range []string{"k3d", "kubectl"} {
		_, err := exec.LookPath(t)
		row(err == nil, false, t+" installed", "brew install "+t)
	}
	_, err := exec.LookPath("helm")
	row(err == nil, true, "helm installed (needed by later courses)", "brew install helm")

	if _, err := exec.LookPath("k3d"); err == nil && dockerOK {
		exists, running, err := a.clusterState()
		switch {
		case err != nil:
			row(false, false, "could not query k3d: "+err.Error(), "check k3d and Docker")
		case !exists:
			row(false, false, fmt.Sprintf("cluster %s exists", a.Cluster), "kdrill cluster up")
		case !running:
			row(false, false, fmt.Sprintf("cluster %s running", a.Cluster), "kdrill cluster up")
		default:
			row(true, false, fmt.Sprintf("cluster %s running", a.Cluster), "")
		}
	}
	if _, err := exec.LookPath("kubectl"); err == nil {
		want := "k3d-" + a.Cluster
		cur, _ := run(exec.CommandContext(a.ctx, "kubectl", "config", "current-context"))
		row(cur == want, true, "kubectl current-context is "+want+" (yours: "+orNone(cur)+")",
			"kubectl config use-context "+want+" (kdrill itself never needs this)")
	}
	if bad > 0 {
		return exitError{1}
	}
	return nil
}

func orNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

// ---------------------------------------------------------------- components ----

func (a *App) compScript(name, which string) string {
	return a.Home + "/base/components/" + name + "/" + which
}

func (a *App) installComponent(name string) error {
	if state.Has(a.st.Components, name) {
		return nil
	}
	script := a.compScript(name, "install.sh")
	if !fileExists(script) {
		return fmt.Errorf("component %q has no install.sh (base/components/%s)", name, name)
	}
	fmt.Printf("installing component %s...\n", name)
	if err := a.runScript(script, a.Home+"/base/components/"+name, "install", nil, 10*time.Minute); err != nil {
		return fmt.Errorf("installing component %s: %w", name, err)
	}
	a.st.Components = append(a.st.Components, name)
	return a.save()
}

func (a *App) uninstallComponent(name string) error {
	script := a.compScript(name, "uninstall.sh")
	if fileExists(script) {
		fmt.Printf("removing component %s...\n", name)
		if err := a.runScript(script, a.Home+"/base/components/"+name, "uninstall", nil, 10*time.Minute); err != nil {
			return fmt.Errorf("removing component %s: %w", name, err)
		}
	}
	a.st.Components = state.Remove(a.st.Components, name)
	return a.save()
}
