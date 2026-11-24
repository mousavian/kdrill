package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"kdrill/internal/state"
)

func write(t *testing.T, p, s string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// A local course needs no cluster, docker or k3d: start, edit, restart a later
// lesson (no clobber), reset (backup), verify, cleanup, plus a renamed course.
func TestLocalCourseLifecycle(t *testing.T) {
	home, st, work := t.TempDir(), t.TempDir(), t.TempDir()
	t.Setenv("KDRILL_HOME", home)
	t.Setenv("KDRILL_STATE_DIR", st)
	t.Setenv("KDRILL_WORK", work)
	t.Setenv("KDRILL_CLUSTER", "kdrill-test-nonexistent")
	t.Setenv("PATH", "/usr/bin:/bin") // no k3d, no kubectl, no docker on purpose
	real, err := os.ReadFile("../../base/lib/common.sh")
	if err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(home, "base/lib/common.sh"), string(real))
	c := filepath.Join(home, "courses/loc")
	write(t, filepath.Join(c, "course.yaml"), "title: L\nkind: local\nformerly: [oldloc]\n")
	l1, l2 := filepath.Join(c, "lessons/01-a"), filepath.Join(c, "lessons/02-b")
	write(t, filepath.Join(l1, "lesson.yaml"), "title: A\ngoal: g\n")
	write(t, filepath.Join(l1, "starter/a.py"), "starter A\n")
	write(t, filepath.Join(l1, "starter/sub/x.txt"), "starter X\n")
	write(t, filepath.Join(l1, "setup.sh"), "echo \"ws=$KDRILL_WORKSPACE\" > \"$KDRILL_WORKSPACE/setup-ran\"\n")
	write(t, filepath.Join(l1, "verify.sh"), "check 'a.py edited' grep -q mine \"$KDRILL_WORKSPACE/a.py\"\n")
	write(t, filepath.Join(l2, "lesson.yaml"), "title: B\ngoal: g\n")
	write(t, filepath.Join(l2, "starter/a.py"), "starter A from lesson 2\n")
	write(t, filepath.Join(l2, "starter/b.py"), "starter B\n")
	// a state from before the rename
	write(t, filepath.Join(st, "state.json"),
		`{"profile":"lite","startedCourses":["oldloc"],"progress":{"oldloc":{"01-a":{"attempts":1,"completedAt":"2026-01-01T00:00:00Z"}}}}`)

	ws := filepath.Join(work, "loc")
	if code := Run([]string{"start", "loc/01"}, home); code != 0 {
		t.Fatalf("start exit %d", code)
	}
	s, _ := state.Load(filepath.Join(st, "state.json"))
	if !s.Done("loc", "01-a") || s.Progress["oldloc"] != nil {
		t.Fatalf("progress not migrated: %+v", s.Progress)
	}
	if read(t, filepath.Join(ws, "a.py")) != "starter A\n" || !strings.Contains(read(t, filepath.Join(ws, "setup-ran")), ws) {
		t.Fatal("starter or setup env missing")
	}
	if code := Run([]string{"verify"}, home); code != 1 {
		t.Fatalf("verify on the untouched starter should fail, got %d", code)
	}
	write(t, filepath.Join(ws, "a.py"), "mine\n")
	if code := Run([]string{"verify"}, home); code != 0 {
		t.Fatalf("verify exit %d", code)
	}
	// next lesson: the learner's a.py is not overwritten, the new file arrives
	if code := Run([]string{"next"}, home); code != 0 {
		t.Fatalf("next exit %d", code)
	}
	if read(t, filepath.Join(ws, "a.py")) != "mine\n" || read(t, filepath.Join(ws, "b.py")) != "starter B\n" {
		t.Fatal("next lesson clobbered or missed files")
	}
	// reset lesson 2: a.py of lesson 2 is also a starter file, so it is backed up and replaced
	write(t, filepath.Join(ws, "b.py"), "my b work\n")
	if code := Run([]string{"reset"}, home); code != 0 {
		t.Fatalf("reset exit %d", code)
	}
	if read(t, filepath.Join(ws, "b.py")) != "starter B\n" {
		t.Fatal("reset did not restore the starter")
	}
	backups, _ := filepath.Glob(filepath.Join(ws, ".backup", "*", "b.py"))
	if len(backups) != 1 || read(t, backups[0]) != "my b work\n" {
		t.Fatalf("backup missing: %v", backups)
	}
	if code := Run([]string{"cleanup"}, home); code != 0 {
		t.Fatalf("cleanup exit %d", code)
	}
	if read(t, filepath.Join(ws, "b.py")) != "starter B\n" {
		t.Fatal("cleanup touched the workspace")
	}
	if code := Run([]string{"status"}, home); code != 0 {
		t.Fatal("status failed without a cluster")
	}
}
