package course

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestSplitHints(t *testing.T) {
	in := "first\nline\n---\nsecond\n---\n\n---\nthird `---` inline\n----\nstill third\n"
	got := SplitHints(in)
	want := []string{"first\nline", "second", "third `---` inline\n----\nstill third"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %q want %q", got, want)
	}
	if len(SplitHints("")) != 0 {
		t.Fatal("empty input should give no hints")
	}
}

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestResolveAndOrder(t *testing.T) {
	home := t.TempDir()
	write(t, filepath.Join(home, "courses/demo/course.yaml"), "title: Demo\nkind: sim\n")
	for _, d := range []string{"10-last", "02-second", "01-first"} {
		write(t, filepath.Join(home, "courses/demo/lessons", d, "lesson.yaml"), "title: T "+d+"\n")
	}
	write(t, filepath.Join(home, "courses/demo/lessons/notalesson/README.md"), "x")

	c, ls, i, err := Resolve(home, "demo/02")
	if err != nil {
		t.Fatal(err)
	}
	if c.ID != "demo" || len(ls) != 3 || ls[i].ID != "02-second" {
		t.Fatalf("bad resolve: %v %v %d", c.ID, ls, i)
	}
	if ls[0].ID != "01-first" || ls[2].ID != "10-last" {
		t.Fatalf("bad order: %v", ls)
	}
	if _, _, i, _ := Resolve(home, "demo/10-last"); i != 2 {
		t.Fatal("full name should resolve")
	}
	if _, _, i, _ := Resolve(home, "demo/1"); i != 0 {
		t.Fatal("unpadded number should resolve")
	}
	if _, _, _, err := Resolve(home, "demo/03"); err == nil {
		t.Fatal("missing lesson should error")
	}
	if _, _, _, err := Resolve(home, "demo"); err == nil {
		t.Fatal("ref without lesson should error")
	}
	if ls[1].Label() != "demo.02-second" || ls[1].NS() != "drill" || ls[1].EffectiveKind(c) != "sim" {
		t.Fatalf("defaults wrong: %+v", ls[1])
	}
}
