package engine

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"
	"time"

	"kdrill/internal/course"
	"kdrill/internal/state"
)

// ---------------------------------------------------------------- listing ----

func (a *App) courses() error {
	cs, err := course.All(a.Home)
	if err != nil {
		return err
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "ID\tTITLE\tPROGRESS")
	for _, c := range cs {
		ls, _ := c.Lessons()
		fmt.Fprintf(tw, "%s\t%s\t%d/%d\n", c.ID, c.Title, a.st.DoneCount(c.ID), len(ls))
	}
	return tw.Flush()
}

func (a *App) lessons(id string) error {
	c, err := course.Load(a.Home, id)
	if err != nil {
		return err
	}
	ls, err := c.Lessons()
	if err != nil {
		return err
	}
	fmt.Printf("%s - %s\n", c.ID, c.Title)
	for _, l := range ls {
		mark := " "
		if a.st.Done(c.ID, l.ID) {
			mark = "✓"
		}
		active := ""
		if a.st.Active != nil && a.st.Active.Course == c.ID && a.st.Active.Lesson == l.ID {
			active = "  <- active"
		}
		fmt.Printf("  %s %-32s %s%s\n", mark, l.ID, l.Title, active)
	}
	return nil
}

// ---------------------------------------------------------------- courses ----

func (a *App) courseCmd(sub, id string) error {
	c, err := course.Load(a.Home, id)
	if err != nil {
		return err
	}
	if sub == "start" {
		if err := a.requireCluster(); err != nil {
			return err
		}
		if err := a.courseStart(c); err != nil {
			return err
		}
		fmt.Printf("course %s started. Next: kdrill start %s/01\n", c.ID, c.ID)
		return nil
	}
	return a.courseStop(c)
}

func (a *App) courseStart(c course.Course) error {
	for _, comp := range c.Components {
		if err := a.installComponent(comp); err != nil {
			return err
		}
	}
	if s := filepath.Join(c.Dir, "setup.sh"); fileExists(s) {
		if err := a.runScript(s, c.Dir, "install", nil, 10*time.Minute); err != nil {
			return fmt.Errorf("course setup.sh: %w", err)
		}
	}
	if !state.Has(a.st.Courses, c.ID) {
		a.st.Courses = append(a.st.Courses, c.ID)
	}
	return a.save()
}

func (a *App) courseStop(c course.Course) error {
	if err := a.requireCluster(); err != nil {
		return err
	}
	if s := filepath.Join(c.Dir, "teardown.sh"); fileExists(s) {
		if err := a.runScript(s, c.Dir, "uninstall", nil, 10*time.Minute); err != nil {
			return fmt.Errorf("course teardown.sh: %w", err)
		}
	}
	a.st.Courses = state.Remove(a.st.Courses, c.ID)
	for _, comp := range c.Components {
		if comp == "kwok" || !state.Has(a.st.Components, comp) || a.usedByStartedCourse(comp) {
			continue
		}
		if err := a.uninstallComponent(comp); err != nil {
			return err
		}
	}
	if err := a.save(); err != nil {
		return err
	}
	fmt.Printf("course %s stopped\n", c.ID)
	return nil
}

func (a *App) usedByStartedCourse(comp string) bool {
	for _, id := range a.st.Courses {
		if c, err := course.Load(a.Home, id); err == nil && state.Has(c.Components, comp) {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------- active lesson ----

type lessonCtx struct {
	c  course.Course
	ls []course.Lesson
	i  int
}

func (x lessonCtx) lesson() course.Lesson { return x.ls[x.i] }

func (a *App) loadActive() (lessonCtx, error) {
	act := a.st.Active
	if act == nil {
		return lessonCtx{}, fmt.Errorf("no active lesson; start one with: kdrill start <course>/<lesson>")
	}
	c, ls, i, err := course.Resolve(a.Home, act.Course+"/"+act.Lesson)
	if err != nil {
		return lessonCtx{}, fmt.Errorf("active lesson %s/%s no longer exists on disk: %w (kdrill cleanup)", act.Course, act.Lesson, err)
	}
	return lessonCtx{c, ls, i}, nil
}

// checkRef fails if an explicit ref does not name the active lesson.
func (a *App) checkRef(ref string) error {
	if ref == "" {
		return nil
	}
	_, ls, i, err := course.Resolve(a.Home, ref)
	if err != nil {
		return err
	}
	l := ls[i]
	if a.st.Active == nil {
		return fmt.Errorf("%s is not the active lesson (none active); run: kdrill start %s", l.Ref(), l.Ref())
	}
	if a.st.Active.Course != l.Course || a.st.Active.Lesson != l.ID {
		return fmt.Errorf("%s is not the active lesson (active: %s/%s); run: kdrill start %s",
			l.Ref(), a.st.Active.Course, a.st.Active.Lesson, l.Ref())
	}
	return nil
}

func (a *App) activeCmd(cmd, ref string) error {
	if cmd == "cleanup" && a.st.Active == nil && ref == "" {
		return a.cleanup()
	}
	if err := a.checkRef(ref); err != nil {
		return err
	}
	switch cmd {
	case "hint":
		return a.hint()
	case "verify":
		return a.verify()
	case "cleanup":
		return a.cleanup()
	case "reset":
		x, err := a.loadActive()
		if err != nil {
			return err
		}
		if err := a.cleanup(); err != nil {
			return err
		}
		return a.startLesson(x.c, x.lesson())
	case "next":
		return a.next()
	}
	return nil
}

func (a *App) lessonEnv(c course.Course, l course.Lesson) []string {
	return []string{
		"KDRILL_LESSON=" + l.Label(),
		"KDRILL_LESSON_DIR=" + l.Dir,
		"KDRILL_NS=" + l.NS(),
	}
}

func (a *App) startRef(ref string) error {
	c, ls, i, err := course.Resolve(a.Home, ref)
	if err != nil {
		return err
	}
	return a.startLesson(c, ls[i])
}

func (a *App) startLesson(c course.Course, l course.Lesson) error {
	if err := a.requireCluster(); err != nil {
		return err
	}
	if a.st.Active != nil {
		fmt.Printf("cleaning up the active lesson (%s/%s) first...\n", a.st.Active.Course, a.st.Active.Lesson)
		if err := a.cleanup(); err != nil {
			return err
		}
	}
	if !state.Has(a.st.Courses, c.ID) {
		fmt.Printf("starting course %s...\n", c.ID)
		if err := a.courseStart(c); err != nil {
			return err
		}
	}
	fmt.Printf("setting up %s...\n", l.Ref())
	if err := a.setSimTaint(l.EffectiveKind(c) == "sim"); err != nil {
		return err
	}
	for _, ns := range l.Namespaces {
		a.k("create", "namespace", ns) // AlreadyExists is fine
		if _, err := a.k("label", "namespace", ns, course.LabelKey+"="+l.Label(), "--overwrite"); err != nil {
			return err
		}
	}
	a.k("config", "set-context", "--current", "--namespace="+l.NS())
	// The user's own kubeconfig: normal environment, best effort.
	run(exec.CommandContext(a.ctx, "kubectl", "config", "set-context", "k3d-"+a.Cluster, "--namespace="+l.NS()))

	// Record first so reset/cleanup work even if setup.sh fails half way.
	a.st.Active = &state.Active{Course: c.ID, Lesson: l.ID, StartedAt: time.Now()}
	if err := a.save(); err != nil {
		return err
	}
	if s := filepath.Join(l.Dir, "setup.sh"); fileExists(s) {
		if err := a.runScript(s, l.Dir, "setup", a.lessonEnv(c, l), l.TimeoutDuration()); err != nil {
			return fmt.Errorf("setup failed: %w\n  try: kdrill reset", err)
		}
	}
	fmt.Println()
	a.printTask(l)
	fmt.Println("\n---\nkdrill verify | hint | reset | solution | show")
	return nil
}

func (a *App) printTask(l course.Lesson) {
	fmt.Printf("%s\n", l.Title)
	fmt.Printf("Goal: %s\n\n", strings.Join(strings.Fields(l.Goal), " "))
	if b, err := os.ReadFile(filepath.Join(l.Dir, "README.md")); err == nil {
		fmt.Println(strings.TrimSpace(string(b)))
	}
}

// show prints a lesson's task: the active one, or the one named by ref.
func (a *App) show(ref string) error {
	if ref == "" {
		x, err := a.loadActive()
		if err != nil {
			return err
		}
		a.printTask(x.lesson())
		return nil
	}
	_, ls, i, err := course.Resolve(a.Home, ref)
	if err != nil {
		return err
	}
	a.printTask(ls[i])
	return nil
}

func (a *App) status() error {
	x, err := a.loadActive()
	if err != nil {
		fmt.Println("active lesson: none")
	} else {
		l := x.lesson()
		fmt.Printf("active lesson: %s (%s)\n", l.Ref(), l.Title)
		fmt.Printf("goal: %s\n", strings.Join(strings.Fields(l.Goal), " "))
		fmt.Printf("hints shown: %d, namespace: %s\n", a.st.Active.HintsShown, l.NS())
	}
	exists, running, cerr := a.clusterState()
	switch {
	case cerr != nil:
		fmt.Println("cluster: unknown (" + cerr.Error() + ")")
	case !exists:
		fmt.Printf("cluster %s: does not exist (kdrill cluster up)\n", a.Cluster)
	case !running:
		fmt.Printf("cluster %s: stopped (kdrill cluster up)\n", a.Cluster)
	default:
		fmt.Printf("cluster %s: running\n", a.Cluster)
	}
	want := "k3d-" + a.Cluster
	if cur, err := run(exec.CommandContext(a.ctx, "kubectl", "config", "current-context")); err == nil && cur != want {
		fmt.Printf("warning: your kubectl context is %q, not %q.\n  switch with: kubectl config use-context %s\n  or use: KUBECONFIG=%s kubectl ...\n",
			cur, want, want, a.kubeconfigPath())
	}
	return nil
}

func (a *App) profile(p string) error {
	if p == "" {
		fmt.Println(a.st.Profile)
		return nil
	}
	if p != "lite" && p != "full" {
		return fmt.Errorf("profile must be lite or full")
	}
	a.st.Profile = p
	if err := a.save(); err != nil {
		return err
	}
	fmt.Printf("profile set to %s (applies the next time a lesson is started)\n", p)
	return nil
}

func (a *App) hint() error {
	x, err := a.loadActive()
	if err != nil {
		return err
	}
	b, _ := os.ReadFile(filepath.Join(x.lesson().Dir, "hints.md"))
	hints := course.SplitHints(string(b))
	if len(hints) == 0 {
		fmt.Println("this lesson has no hints; see: kdrill solution")
		return nil
	}
	n := a.st.Active.HintsShown
	if n >= len(hints) {
		fmt.Printf("no more hints (all %d shown). See the full answer with: kdrill solution\n", len(hints))
		return nil
	}
	fmt.Printf("Hint %d/%d\n%s\n", n+1, len(hints), hints[n])
	a.st.Active.HintsShown = n + 1
	return a.save()
}

func (a *App) verify() error {
	x, err := a.loadActive()
	if err != nil {
		return err
	}
	if err := a.requireCluster(); err != nil {
		return err
	}
	l := x.lesson()
	script := filepath.Join(l.Dir, "verify.sh")
	if !fileExists(script) {
		return fmt.Errorf("lesson has no verify.sh")
	}
	rerr := a.runScript(script, l.Dir, "verify", a.lessonEnv(x.c, l), l.TimeoutDuration())
	p := a.st.Lesson(l.Course, l.ID)
	p.Attempts++
	if rerr != nil {
		if err := a.save(); err != nil {
			return err
		}
		fmt.Println("\nnot there yet. Need a nudge? kdrill hint")
		return exitError{1}
	}
	now := time.Now()
	p.CompletedAt = &now
	if err := a.save(); err != nil {
		return err
	}
	fmt.Printf("\nAll checks passed - lesson complete (%d attempt(s)). Continue with: kdrill next\n", p.Attempts)
	return nil
}

func (a *App) cleanup() error {
	x, lerr := a.loadActive()
	exists, running, err := a.clusterState()
	if err != nil {
		return err
	}
	if !exists || !running {
		fmt.Println("cluster is not running; nothing to clean in it")
		a.st.Active = nil
		return a.save()
	}
	if lerr == nil {
		l := x.lesson()
		if s := filepath.Join(l.Dir, "cleanup.sh"); fileExists(s) {
			if err := a.runScript(s, l.Dir, "cleanup", a.lessonEnv(x.c, l), l.TimeoutDuration()); err != nil {
				fmt.Fprintf(os.Stderr, "warning: cleanup.sh failed: %v (continuing)\n", err)
			}
		}
	}
	if _, err := a.k("delete", "namespace", "-l", course.LabelKey, "--ignore-not-found", "--timeout=120s"); err != nil {
		// Fake (KWOK) pods can get stuck Terminating, e.g. after a cluster restart.
		fmt.Fprintln(os.Stderr, "warning: namespace deletion is slow; force-deleting leftover pods")
		if nss, err := a.k("get", "namespace", "-l", course.LabelKey, "-o", "name"); err == nil {
			for _, ns := range strings.Fields(nss) {
				a.k("delete", "pods", "--all", "-n", strings.TrimPrefix(ns, "namespace/"), "--force", "--grace-period=0", "--wait=false")
			}
		}
		a.k("delete", "namespace", "-l", course.LabelKey, "--ignore-not-found", "--timeout=60s")
	}
	kinds, err := a.k("api-resources", "--namespaced=false", "--verbs=delete", "-o", "name")
	if err == nil {
		var names []string
		for _, k := range strings.Fields(kinds) {
			if k != "namespaces" {
				names = append(names, k)
			}
		}
		a.k("delete", strings.Join(names, ","), "-l", course.LabelKey, "--ignore-not-found")
	}
	a.st.Active = nil
	if err := a.save(); err != nil {
		return err
	}
	fmt.Println("  cleaned up")
	return nil
}

func (a *App) next() error {
	x, err := a.loadActive()
	if err != nil {
		return err
	}
	if err := a.cleanup(); err != nil {
		return err
	}
	if x.i+1 >= len(x.ls) {
		fmt.Printf("course %s complete (%d/%d lessons done). Pick another with: kdrill courses\n",
			x.c.ID, a.st.DoneCount(x.c.ID), len(x.ls))
		return nil
	}
	return a.startLesson(x.c, x.ls[x.i+1])
}

func (a *App) solution(ref string) error {
	var l course.Lesson
	if ref == "" {
		x, err := a.loadActive()
		if err != nil {
			return err
		}
		l = x.lesson()
	} else {
		_, ls, i, err := course.Resolve(a.Home, ref)
		if err != nil {
			return err
		}
		l = ls[i]
	}
	dir := filepath.Join(l.Dir, "solution")
	if b, err := os.ReadFile(filepath.Join(dir, "README.md")); err == nil {
		fmt.Println(strings.TrimSpace(string(b)))
	} else {
		fmt.Println("(no solution/README.md)")
	}
	var others []string
	filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err == nil && !d.IsDir() && p != filepath.Join(dir, "README.md") {
			others = append(others, p)
		}
		return nil
	})
	if len(others) > 0 {
		fmt.Println("\nOther solution files:")
		for _, p := range others {
			fmt.Println("  " + p)
		}
	}
	return nil
}

// setSimTaint taints (or untaints) the real nodes. During sim lessons the
// taint keeps lesson pods off the real node so they only land on fake nodes.
func (a *App) setSimTaint(on bool) error {
	const taint = "node-role.kubernetes.io/control-plane"
	if on {
		_, err := a.k("taint", "node", "-l", "!type", taint+"=:NoSchedule", "--overwrite")
		return err
	}
	a.k("taint", "node", "-l", "!type", taint+":NoSchedule-") // fails when absent; fine
	return nil
}
