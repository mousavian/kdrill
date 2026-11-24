package engine

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"
	"time"

	"kdrill/internal/course"
	"kdrill/internal/state"
)

// status prints everything kdrill knows in one place: cluster, kubectl
// context, profile, components, the active lesson and course progress.
// With a course id it lists that course's lessons instead of all courses.
func (a *App) status(courseID string) error {
	var only *course.Course
	if courseID != "" {
		c, err := course.Load(a.Home, courseID)
		if err != nil {
			return err
		}
		only = &c
	}

	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	if a.activeIsLocal() {
		fmt.Fprintf(tw, "cluster\tnot needed for the active (local) lesson; %s\n", a.clusterLine())
	} else {
		fmt.Fprintf(tw, "cluster\t%s\n", a.clusterLine())
		fmt.Fprintf(tw, "kubectl\t%s\n", a.contextLine())
	}
	fmt.Fprintf(tw, "workspace root\t%s\n", workRoot())
	fmt.Fprintf(tw, "profile\t%s\n", a.st.Profile)
	fmt.Fprintf(tw, "components\t%s\n", orNone(strings.Join(a.st.Components, ", ")))
	fmt.Fprintf(tw, "courses started\t%s\n", orNone(strings.Join(a.st.Courses, ", ")))
	tw.Flush()

	fmt.Println()
	a.activeSection()

	fmt.Println()
	if only != nil {
		return a.lessonTable(*only)
	}
	return a.courseTable()
}

// activeIsLocal reports whether the active lesson is a kind: local lesson.
func (a *App) activeIsLocal() bool {
	if a.st.Active == nil {
		return false
	}
	x, err := a.loadActive()
	return err == nil && x.lesson().IsLocal(x.c)
}

// clusterLine describes the k3d cluster and, when it runs, its nodes.
func (a *App) clusterLine() string {
	exists, running, err := a.clusterState()
	switch {
	case err != nil:
		return "unknown (" + err.Error() + "; try: kdrill doctor)"
	case !exists:
		return a.Cluster + ": does not exist (kdrill cluster up)"
	case !running:
		return a.Cluster + ": stopped (kdrill cluster up)"
	}
	line := a.Cluster + ": running"
	if !fileExists(a.kubeconfigPath()) {
		return line
	}
	out, err := a.k("get", "nodes", "-o", "json", "--request-timeout=5s")
	if err != nil {
		return line + " (API not answering yet)"
	}
	var nl struct {
		Items []struct {
			Metadata struct {
				Annotations map[string]string `json:"annotations"`
			} `json:"metadata"`
			Status struct {
				NodeInfo struct {
					KubeletVersion string `json:"kubeletVersion"`
				} `json:"nodeInfo"`
				Conditions []struct {
					Type, Status string
				} `json:"conditions"`
			} `json:"status"`
		} `json:"items"`
	}
	if json.Unmarshal([]byte(out), &nl) != nil {
		return line
	}
	real, realReady, fake := 0, 0, 0
	version := ""
	for _, n := range nl.Items {
		if n.Metadata.Annotations["kwok.x-k8s.io/node"] == "fake" {
			fake++
			continue
		}
		real++
		version = n.Status.NodeInfo.KubeletVersion
		for _, c := range n.Status.Conditions {
			if c.Type == "Ready" && c.Status == "True" {
				realReady++
			}
		}
	}
	parts := []string{fmt.Sprintf("%d/%d real node(s) Ready", realReady, real)}
	if fake > 0 {
		parts = append(parts, fmt.Sprintf("%d fake", fake))
	}
	if version != "" {
		parts = append(parts, version)
	}
	return line + ", " + strings.Join(parts, ", ")
}

func (a *App) contextLine() string {
	want := "k3d-" + a.Cluster
	cur, err := run(exec.CommandContext(a.ctx, "kubectl", "config", "current-context"))
	switch {
	case err != nil:
		return fmt.Sprintf("no current context; switch with: kubectl config use-context %s", want)
	case cur != want:
		return fmt.Sprintf("WARNING your context is %q, not %q\n\t  switch with: kubectl config use-context %s\n\t  or use: KUBECONFIG=%s kubectl ...",
			cur, want, want, a.kubeconfigPath())
	}
	return cur + " ✓"
}

func (a *App) activeSection() {
	if a.st.Active == nil {
		fmt.Println("active lesson: none (kdrill start <course>/<lesson>)")
		return
	}
	x, err := a.loadActive()
	if err != nil {
		fmt.Println("active lesson: " + err.Error())
		return
	}
	l := x.lesson()
	fmt.Printf("active lesson: %s - %s\n", l.Ref(), l.Title)
	fmt.Printf("  goal:      %s\n", strings.Join(strings.Fields(l.Goal), " "))
	b, _ := os.ReadFile(filepath.Join(l.Dir, "hints.md"))
	verified := "not yet (kdrill verify)"
	if p := a.st.Progress[x.c.ID][l.ID]; p != nil && p.CompletedAt != nil {
		verified = "passed " + ago(*p.CompletedAt)
	}
	ns := "   namespace: " + l.NS()
	if l.IsLocal(x.c) {
		ns = "" // no cluster, no namespace
	}
	fmt.Printf("  kind:      %s%s   started: %s   hints: %d/%d\n",
		l.EffectiveKind(x.c), ns, ago(a.st.Active.StartedAt),
		a.st.Active.HintsShown, len(course.SplitHints(string(b))))
	if l.IsLocal(x.c) {
		fmt.Printf("  workspace: %s\n", a.workspace(x.c.ID))
	}
	fmt.Printf("  verified:  %s\n", verified)
	if x.i+1 < len(x.ls) {
		fmt.Printf("  next:      %s - %s\n", x.ls[x.i+1].Ref(), x.ls[x.i+1].Title)
	}
}

func (a *App) courseTable() error {
	cs, err := course.All(a.Home)
	if err != nil {
		return err
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "COURSE\tDONE\tSTATE\tTITLE")
	for _, c := range cs {
		ls, _ := c.Lessons()
		fmt.Fprintf(tw, "%s\t%d/%d\t%s\t%s\n", c.ID, a.st.DoneCount(c.ID), len(ls), a.courseState(c.ID), c.Title)
	}
	tw.Flush()
	fmt.Println("\nlessons of one course: kdrill status <course>")
	return nil
}

func (a *App) courseState(id string) string {
	s := "-"
	if state.Has(a.st.Courses, id) {
		s = "started"
	}
	if a.st.Active != nil && a.st.Active.Course == id {
		s += ", active"
	}
	return strings.TrimPrefix(s, "-, ")
}

func (a *App) lessonTable(c course.Course) error {
	ls, err := c.Lessons()
	if err != nil {
		return err
	}
	fmt.Printf("%s - %s (%d/%d done, %s)\n", c.ID, c.Title, a.st.DoneCount(c.ID), len(ls), a.courseState(c.ID))
	for _, l := range ls {
		mark := " "
		if a.st.Done(c.ID, l.ID) {
			mark = "✓"
		}
		active := ""
		if a.st.Active != nil && a.st.Active.Course == c.ID && a.st.Active.Lesson == l.ID {
			active = "  <- active"
		}
		fmt.Printf("  %s %-34s %s%s\n", mark, l.ID, l.Title, active)
	}
	return nil
}

// ago renders a time as a rough "N units ago".
func ago(t time.Time) string {
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%dm ago", int(d.Minutes()))
	case d < 48*time.Hour:
		return fmt.Sprintf("%dh ago", int(d.Hours()))
	}
	return fmt.Sprintf("%dd ago", int(d.Hours()/24))
}
