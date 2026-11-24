// Package state persists kdrill progress in $KDRILL_STATE_DIR/state.json.
package state

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"
)

// Active is the lesson currently set up in the cluster.
type Active struct {
	Course     string    `json:"course"`
	Lesson     string    `json:"lesson"`
	StartedAt  time.Time `json:"startedAt"`
	HintsShown int       `json:"hintsShown"`
}

// Progress is the record for one lesson.
type Progress struct {
	Attempts    int        `json:"attempts"`
	CompletedAt *time.Time `json:"completedAt,omitempty"`
}

type State struct {
	Profile    string                          `json:"profile"`
	Active     *Active                         `json:"active,omitempty"`
	Components []string                        `json:"components"`
	Courses    []string                        `json:"startedCourses"`
	Progress   map[string]map[string]*Progress `json:"progress"` // course -> lesson dir -> progress
}

// Load reads the state file; a missing file yields a fresh state.
func Load(path string) (*State, error) {
	s := &State{}
	b, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	if err == nil {
		if err := json.Unmarshal(b, s); err != nil {
			return nil, err
		}
	}
	if s.Profile == "" {
		s.Profile = "lite"
	}
	if s.Progress == nil {
		s.Progress = map[string]map[string]*Progress{}
	}
	return s, nil
}

// Save writes the state atomically (temp file + rename).
func (s *State) Save(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".state-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(append(b, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

// Lesson returns (creating if needed) the progress record of a lesson.
func (s *State) Lesson(course, lesson string) *Progress {
	m := s.Progress[course]
	if m == nil {
		m = map[string]*Progress{}
		s.Progress[course] = m
	}
	p := m[lesson]
	if p == nil {
		p = &Progress{}
		m[lesson] = p
	}
	return p
}

// Done reports whether a lesson has been completed.
func (s *State) Done(course, lesson string) bool {
	p := s.Progress[course][lesson]
	return p != nil && p.CompletedAt != nil
}

// DoneCount counts completed lessons of a course.
func (s *State) DoneCount(course string) int {
	n := 0
	for _, p := range s.Progress[course] {
		if p.CompletedAt != nil {
			n++
		}
	}
	return n
}

func Has(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func Remove(list []string, v string) []string {
	var out []string
	for _, x := range list {
		if x != v {
			out = append(out, x)
		}
	}
	return out
}

// Migrate moves everything recorded under a former course id to the new one:
// progress, started-course entries and the active lesson. renames maps
// old id -> new id. It reports whether anything changed.
func (s *State) Migrate(renames map[string]string) bool {
	changed := false
	for old, nw := range renames {
		if old == nw {
			continue
		}
		if m, ok := s.Progress[old]; ok {
			dst := s.Progress[nw]
			if dst == nil {
				dst = map[string]*Progress{}
				s.Progress[nw] = dst
			}
			for lesson, p := range m {
				// Keep what the new id already has unless the old record is better.
				if cur := dst[lesson]; cur == nil || (cur.CompletedAt == nil && p.CompletedAt != nil) {
					dst[lesson] = p
				}
			}
			delete(s.Progress, old)
			changed = true
		}
		if Has(s.Courses, old) {
			s.Courses = Remove(s.Courses, old)
			if !Has(s.Courses, nw) {
				s.Courses = append(s.Courses, nw)
			}
			changed = true
		}
		if s.Active != nil && s.Active.Course == old {
			s.Active.Course = nw
			changed = true
		}
	}
	return changed
}
