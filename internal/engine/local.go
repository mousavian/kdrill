package engine

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"kdrill/internal/course"
	"kdrill/internal/state"
)

// Local courses (kind: local) run the learner's code in a container and need
// no cluster. The learner's files live in a per-course workspace outside the
// repo; lessons build on each other there.

func homeDir() string {
	h, _ := os.UserHomeDir()
	return h
}

// workRoot is $KDRILL_WORK or ~/kdrill-work.
func workRoot() string {
	if v := os.Getenv("KDRILL_WORK"); v != "" {
		return v
	}
	return filepath.Join(homeDir(), "kdrill-work")
}

// workspace is the learner's directory for one course.
func (a *App) workspace(courseID string) string { return filepath.Join(workRoot(), courseID) }

// cacheDir is the download cache of one course: $KDRILL_CACHE/<course> or ~/.cache/kdrill/<course>.
func (a *App) cacheDir(courseID string) string {
	if v := os.Getenv("KDRILL_CACHE"); v != "" {
		return filepath.Join(v, courseID)
	}
	return filepath.Join(homeDir(), ".cache", "kdrill", courseID)
}

// localEnv is what scripts of a local course get besides the usual KDRILL_* variables.
func (a *App) localEnv(c course.Course) []string {
	bin, _ := os.Executable()
	return []string{
		"KDRILL_WORK=" + workRoot(),
		"KDRILL_WORKSPACE=" + a.workspace(c.ID),
		"KDRILL_CACHE_DIR=" + a.cacheDir(c.ID),
		"KDRILL_IMAGE=" + c.Image,
		"KDRILL_BIN=" + bin,
		"KDRILL_COURSE=" + c.ID,
	}
}

func (a *App) courseEnv(c course.Course) []string {
	if c.Kind == "local" {
		return a.localEnv(c)
	}
	return nil
}

// ensureImage builds the course image when it is not in Docker yet.
func (a *App) ensureImage(c course.Course) error {
	if c.Image == "" {
		return nil
	}
	if _, err := run(exec.CommandContext(a.ctx, "docker", "image", "inspect", c.Image)); err == nil {
		return nil
	}
	if c.ImageBuild == "" {
		return fmt.Errorf("image %s is missing and the course has no image_build", c.Image)
	}
	script := filepath.Join(a.Home, c.ImageBuild)
	if !fileExists(script) {
		return fmt.Errorf("image_build %s does not exist", c.ImageBuild)
	}
	fmt.Printf("building %s (first time only)...\n", c.Image)
	if err := a.runScript(script, filepath.Dir(script), "install", a.localEnv(c), 30*time.Minute); err != nil {
		return fmt.Errorf("building %s: %w", c.Image, err)
	}
	return nil
}

// copyStarter copies the lesson's starter/ files into the workspace without
// overwriting anything. It returns the relative paths it created.
func copyStarter(l course.Lesson, ws string) ([]string, error) {
	var created []string
	err := walkStarter(l, func(rel, src string) error {
		dst := filepath.Join(ws, rel)
		if _, err := os.Stat(dst); err == nil {
			return nil
		}
		if err := copyFile(src, dst); err != nil {
			return err
		}
		created = append(created, rel)
		return nil
	})
	return created, err
}

func walkStarter(l course.Lesson, fn func(rel, src string) error) error {
	root := filepath.Join(l.Dir, "starter")
	if fi, err := os.Stat(root); err != nil || !fi.IsDir() {
		return nil
	}
	return filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(root, p)
		return fn(rel, p)
	})
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	fi, err := in.Stat()
	if err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, fi.Mode().Perm()|0o600)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// prepareLocal makes a course ready for a lesson: started, image built, workspace present.
func (a *App) prepareLocal(c course.Course) (string, error) {
	if !state.Has(a.st.Courses, c.ID) {
		fmt.Printf("starting course %s...\n", c.ID)
		if err := a.ensureImage(c); err != nil {
			return "", err
		}
		if s := filepath.Join(c.Dir, "setup.sh"); fileExists(s) {
			if err := a.runScript(s, c.Dir, "install", a.localEnv(c), 10*time.Minute); err != nil {
				return "", fmt.Errorf("course setup.sh: %w", err)
			}
		}
		a.st.Courses = append(a.st.Courses, c.ID)
		if err := a.save(); err != nil {
			return "", err
		}
	} else if err := a.ensureImage(c); err != nil {
		return "", err
	}
	ws := a.workspace(c.ID)
	if err := os.MkdirAll(ws, 0o755); err != nil {
		return "", err
	}
	return ws, nil
}

func (a *App) startLocal(c course.Course, l course.Lesson) error {
	if a.st.Active != nil {
		fmt.Printf("closing the active lesson (%s/%s) first...\n", a.st.Active.Course, a.st.Active.Lesson)
		if err := a.cleanup(); err != nil {
			// A cluster lesson left behind and no cluster to clean: not our problem here.
			fmt.Fprintf(os.Stderr, "warning: %v (continuing; no cluster is needed for this lesson)\n", err)
			a.st.Active = nil
		}
	}
	ws, err := a.prepareLocal(c)
	if err != nil {
		return err
	}
	fmt.Printf("setting up %s...\n", l.Ref())
	created, err := copyStarter(l, ws)
	if err != nil {
		return err
	}
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
	a.printTask(c, l)
	if len(created) > 0 {
		fmt.Printf("\nNew files in your workspace: %s\n", strings.Join(created, ", "))
	}
	fmt.Println("\n---\nkdrill verify | hint | reset | solution | show | py")
	return nil
}

// resetLocal moves the learner's versions of the lesson's starter files to
// .backup/<timestamp>/ and restores the starter files.
func (a *App) resetLocal(c course.Course, l course.Lesson) error {
	ws, err := a.prepareLocal(c)
	if err != nil {
		return err
	}
	backup := filepath.Join(ws, ".backup", time.Now().Format("20060102-150405"))
	var moved []string
	err = walkStarter(l, func(rel, src string) error {
		dst := filepath.Join(ws, rel)
		if _, err := os.Stat(dst); err == nil {
			b := filepath.Join(backup, rel)
			if err := os.MkdirAll(filepath.Dir(b), 0o755); err != nil {
				return err
			}
			if err := os.Rename(dst, b); err != nil {
				return err
			}
			moved = append(moved, rel)
		}
		return copyFile(src, dst)
	})
	if err != nil {
		return err
	}
	if len(moved) > 0 {
		fmt.Printf("your versions of %s are saved in %s\n", strings.Join(moved, ", "), backup)
	}
	a.st.Active = &state.Active{Course: c.ID, Lesson: l.ID, StartedAt: time.Now()}
	if err := a.save(); err != nil {
		return err
	}
	if s := filepath.Join(l.Dir, "setup.sh"); fileExists(s) {
		if err := a.runScript(s, l.Dir, "setup", a.lessonEnv(c, l), l.TimeoutDuration()); err != nil {
			return fmt.Errorf("setup failed: %w", err)
		}
	}
	fmt.Println()
	a.printTask(c, l)
	fmt.Println("\n---\nkdrill verify | hint | reset | solution | show | py")
	return nil
}

// cleanupLocal ends the lesson. Nothing in the workspace is removed.
func (a *App) cleanupLocal(c course.Course, l course.Lesson) error {
	if s := filepath.Join(l.Dir, "cleanup.sh"); fileExists(s) {
		if err := a.runScript(s, l.Dir, "cleanup", a.lessonEnv(c, l), l.TimeoutDuration()); err != nil {
			fmt.Fprintf(os.Stderr, "warning: cleanup.sh failed: %v (continuing)\n", err)
		}
	}
	a.st.Active = nil
	if err := a.save(); err != nil {
		return err
	}
	fmt.Printf("  lesson closed; your files in %s are untouched\n", a.workspace(c.ID))
	return nil
}

// ---------------------------------------------------------------- kdrill py ----

// pickLocalCourse chooses the course for `kdrill py`.
func (a *App) pickLocalCourse(explicit string) (course.Course, error) {
	if explicit != "" {
		c, err := course.Load(a.Home, explicit)
		if err != nil {
			return c, err
		}
		if c.Kind != "local" {
			return c, fmt.Errorf("course %s is not a local course", explicit)
		}
		return c, nil
	}
	if a.st.Active != nil {
		if c, err := course.Load(a.Home, a.st.Active.Course); err == nil && c.Kind == "local" {
			return c, nil
		}
	}
	all, _ := course.All(a.Home)
	var locals []course.Course
	for _, c := range all {
		if c.Kind == "local" {
			locals = append(locals, c)
		}
	}
	if len(locals) == 1 {
		return locals[0], nil
	}
	return course.Course{}, fmt.Errorf("no active local lesson; start one (kdrill start <course>/<lesson>) or pass --course <course>")
}

// pyCmd implements `kdrill py [--course C] [--net] [--cache-rw] [--tests DIR] [python args...]`.
func (a *App) pyCmd(args []string) error {
	var explicit, tests string
	net, cacheRW := false, false
	for len(args) > 0 {
		switch args[0] {
		case "--cache-rw":
			cacheRW, args = true, args[1:]
			continue
		case "--course":
			if len(args) < 2 {
				return fmt.Errorf("--course needs a value")
			}
			explicit, args = args[1], args[2:]
			continue
		case "--tests":
			if len(args) < 2 {
				return fmt.Errorf("--tests needs a directory")
			}
			tests, args = args[1], args[2:]
			continue
		case "--net":
			net, args = true, args[1:]
			continue
		}
		break
	}
	c, err := a.pickLocalCourse(explicit)
	if err != nil {
		return err
	}
	if a.st.Active != nil && a.st.Active.Course == c.ID {
		if x, err := a.loadActive(); err == nil && x.lesson().Network {
			net = true
		}
	}
	if err := a.ensureImage(c); err != nil {
		return err
	}
	ws := a.workspace(c.ID)
	cache := a.cacheDir(c.ID)
	for _, d := range []string{ws, cache} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	cpus, mem := "2", "1536m"
	if a.st.Profile == "full" {
		cpus, mem = "4", "3g"
	}
	netMode := "none"
	if net {
		netMode = "bridge"
	}
	dargs := []string{"run", "--rm",
		"--user", fmt.Sprintf("%d:%d", os.Getuid(), os.Getgid()),
		"--cpus", cpus, "--memory", mem, "--memory-swap", mem,
		"-v", ws + ":/work", "-v", cache + ":/cache" + map[bool]string{true: "", false: ":ro"}[cacheRW],
		"-w", "/work",
		"-e", "HOME=/tmp", "-e", "MPLCONFIGDIR=/tmp/mpl",
		"-e", "PYTHONDONTWRITEBYTECODE=1", "-e", "PYTHONUNBUFFERED=1",
		"-e", "OMP_NUM_THREADS=" + cpus, "-e", "MKL_NUM_THREADS=" + cpus,
		"-e", "KDRILL_HOST_WORKSPACE=" + ws,
		"-e", "PYTHONPATH=/work:/kdlib:/opt/kdrill",
	}
	if lib := filepath.Join(c.Dir, "pylib"); dirExists(lib) {
		dargs = append(dargs, "-v", lib+":/kdlib:ro")
	}
	if tests != "" {
		abs, err := filepath.Abs(tests)
		if err != nil {
			return err
		}
		dargs = append(dargs, "-v", abs+":/tests:ro")
	}
	if net {
		for _, k := range []string{"HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"} {
			if v := os.Getenv(k); v != "" {
				dargs = append(dargs, "-e", k+"="+v)
			}
		}
		if ca := os.Getenv("KDRILL_CA"); ca != "" {
			dargs = append(dargs, "-v", ca+":/etc/kdrill-ca.pem:ro",
				"-e", "SSL_CERT_FILE=/etc/kdrill-ca.pem", "-e", "REQUESTS_CA_BUNDLE=/etc/kdrill-ca.pem")
		}
	}
	// KDRILL_DOCKER_ARGS adds docker run flags (e.g. for a proxy); its --network replaces ours.
	extra := strings.Fields(os.Getenv("KDRILL_DOCKER_ARGS"))
	hasNet := false
	for _, e := range extra {
		if e == "--network" || strings.HasPrefix(e, "--network=") {
			hasNet = true
		}
	}
	if !hasNet {
		dargs = append(dargs, "--network", netMode)
	}
	dargs = append(dargs, extra...)
	interactive := isTerminal(os.Stdin)
	if interactive {
		dargs = append(dargs, "-i")
		if len(args) == 0 && isTerminal(os.Stdout) {
			dargs = append(dargs, "-t")
		}
	}
	dargs = append(dargs, c.Image, "python3")
	dargs = append(dargs, args...)
	cmd := exec.CommandContext(a.ctx, "docker", dargs...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return exitError{ee.ExitCode()}
		}
		return err
	}
	return nil
}

func isTerminal(f *os.File) bool {
	fi, err := f.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}

func dirExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}
