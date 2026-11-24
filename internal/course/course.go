// Package course reads courses and lessons from the courses/ directory.
package course

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const LabelKey = "kdrill.dev/lesson"

type Course struct {
	ID          string   `yaml:"-"`
	Title       string   `yaml:"title"`
	Description string   `yaml:"description"`
	Kind        string   `yaml:"kind"`
	Components  []string `yaml:"components"`
	Requires    []string `yaml:"requires"`
	// Formerly lists earlier ids of a renamed course; saved progress under
	// those ids moves to this course (see state.Migrate).
	Formerly []string `yaml:"formerly"`
	Dir      string   `yaml:"-"`
	// Local courses (kind: local) run code in a container and need no cluster.
	Image      string `yaml:"image"`       // image tag used by `kdrill py`
	ImageBuild string `yaml:"image_build"` // script (relative to the repo) that builds it
}

type Lesson struct {
	ID         string   `yaml:"-"` // directory name
	Course     string   `yaml:"-"`
	Dir        string   `yaml:"-"`
	Title      string   `yaml:"title"`
	Goal       string   `yaml:"goal"`
	Kind       string   `yaml:"kind"`
	Concepts   []string `yaml:"concepts"`
	Namespaces []string `yaml:"namespaces"`
	Timeout    string   `yaml:"timeout"`
	Network    bool     `yaml:"network"` // local lessons: `kdrill py` may use the network
}

// Label is the value of the kdrill.dev/lesson label.
func (l Lesson) Label() string { return l.Course + "." + l.ID }

// Ref is the CLI reference, <course>/<lesson>.
func (l Lesson) Ref() string { return l.Course + "/" + l.ID }

func (l Lesson) NS() string { return l.Namespaces[0] }

func (l Lesson) TimeoutDuration() time.Duration {
	if d, err := time.ParseDuration(l.Timeout); err == nil && d > 0 {
		return d
	}
	return 180 * time.Second
}

// EffectiveKind is the lesson kind, falling back to the course kind.
func (l Lesson) EffectiveKind(c Course) string {
	if l.Kind != "" {
		return l.Kind
	}
	if c.Kind != "" {
		return c.Kind
	}
	return "real-light"
}

// IsLocal reports whether the lesson needs no cluster (kind: local).
func (l Lesson) IsLocal(c Course) bool { return l.EffectiveKind(c) == "local" }

func readYAML(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := yaml.Unmarshal(b, v); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	return nil
}

// Load reads one course by id.
func Load(home, id string) (Course, error) {
	dir := filepath.Join(home, "courses", id)
	c := Course{ID: id, Dir: dir}
	if err := readYAML(filepath.Join(dir, "course.yaml"), &c); err != nil {
		if os.IsNotExist(err) {
			return c, fmt.Errorf("no such course %q (see: kdrill status)", id)
		}
		return c, err
	}
	return c, nil
}

// All lists every course, ordered by id.
func All(home string) ([]Course, error) {
	entries, err := os.ReadDir(filepath.Join(home, "courses"))
	if err != nil {
		return nil, err
	}
	var out []Course
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := os.Stat(filepath.Join(home, "courses", e.Name(), "course.yaml")); err != nil {
			continue
		}
		c, err := Load(home, e.Name())
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

// Lessons lists the lessons of a course ordered by directory name.
func (c Course) Lessons() ([]Lesson, error) {
	root := filepath.Join(c.Dir, "lessons")
	entries, err := os.ReadDir(root)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var out []Lesson
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		l := Lesson{ID: e.Name(), Course: c.ID, Dir: filepath.Join(root, e.Name())}
		if err := readYAML(filepath.Join(l.Dir, "lesson.yaml"), &l); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, err
		}
		if len(l.Namespaces) == 0 {
			l.Namespaces = []string{"drill"}
		}
		out = append(out, l)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// Pick finds a lesson by full directory name or by numeric prefix ("01", "1").
func Pick(lessons []Lesson, name string) (int, error) {
	for i, l := range lessons {
		if l.ID == name {
			return i, nil
		}
	}
	if n, err := strconv.Atoi(name); err == nil {
		for i, l := range lessons {
			digits := strings.IndexFunc(l.ID, func(r rune) bool { return r < '0' || r > '9' })
			if digits > 0 {
				if m, err := strconv.Atoi(l.ID[:digits]); err == nil && m == n {
					return i, nil
				}
			}
		}
	}
	return -1, fmt.Errorf("no lesson %q in this course", name)
}

// Resolve turns "<course>/<lesson>" into the course, its lessons and the index of the lesson.
func Resolve(home, ref string) (Course, []Lesson, int, error) {
	cid, lid, ok := strings.Cut(ref, "/")
	if !ok || cid == "" || lid == "" {
		return Course{}, nil, 0, fmt.Errorf("lesson must be <course>/<lesson>, e.g. k8s-scheduling/01")
	}
	c, err := Load(home, cid)
	if err != nil {
		return c, nil, 0, err
	}
	ls, err := c.Lessons()
	if err != nil {
		return c, nil, 0, err
	}
	i, err := Pick(ls, lid)
	if err != nil {
		return c, ls, 0, fmt.Errorf("%w (see: kdrill lessons %s)", err, cid)
	}
	return c, ls, i, nil
}

// SplitHints splits hints.md on lines that are exactly "---".
func SplitHints(text string) []string {
	var out []string
	var cur []string
	flush := func() {
		if s := strings.TrimSpace(strings.Join(cur, "\n")); s != "" {
			out = append(out, s)
		}
		cur = nil
	}
	for _, line := range strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n") {
		if line == "---" {
			flush()
		} else {
			cur = append(cur, line)
		}
	}
	flush()
	return out
}
