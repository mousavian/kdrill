package state

import (
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

func TestRoundTrip(t *testing.T) {
	p := filepath.Join(t.TempDir(), "sub", "state.json")
	s, err := Load(p)
	if err != nil {
		t.Fatal(err)
	}
	if s.Profile != "lite" {
		t.Fatalf("default profile: %q", s.Profile)
	}
	now := time.Now().UTC().Truncate(time.Second)
	s.Profile = "full"
	s.Components = []string{"kwok"}
	s.Active = &Active{Course: "c", Lesson: "01-x", StartedAt: now, HintsShown: 2}
	pr := s.Lesson("c", "01-x")
	pr.Attempts = 3
	pr.CompletedAt = &now
	if err := s.Save(p); err != nil {
		t.Fatal(err)
	}
	got, err := Load(p)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(s, got) {
		t.Fatalf("round trip mismatch:\n%+v\n%+v", s, got)
	}
	if !got.Done("c", "01-x") || got.DoneCount("c") != 1 || got.Done("c", "02") {
		t.Fatal("progress queries wrong")
	}
}

func TestMigrateFormerCourse(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	s := &State{Progress: map[string]map[string]*Progress{
		"training":          {"01-a": {Attempts: 2, CompletedAt: &now}, "02-b": {Attempts: 1}},
		"training-platform": {"02-b": {Attempts: 5, CompletedAt: &now}},
		"other":             {"01-x": {Attempts: 1}},
	}, Courses: []string{"kyverno", "training"},
		Active: &Active{Course: "training", Lesson: "02-b"}}
	if !s.Migrate(map[string]string{"training": "training-platform"}) {
		t.Fatal("expected a change")
	}
	if _, ok := s.Progress["training"]; ok {
		t.Fatal("old progress key remains")
	}
	if !s.Done("training-platform", "01-a") || s.Progress["training-platform"]["02-b"].Attempts != 5 {
		t.Fatalf("progress not merged correctly: %+v", s.Progress["training-platform"])
	}
	if Has(s.Courses, "training") || !Has(s.Courses, "training-platform") || !Has(s.Courses, "kyverno") {
		t.Fatalf("started courses: %v", s.Courses)
	}
	if s.Active.Course != "training-platform" {
		t.Fatalf("active: %+v", s.Active)
	}
	if s.Migrate(map[string]string{"training": "training-platform"}) {
		t.Fatal("second migration must be a no-op")
	}
	// round trip through disk
	p := filepath.Join(t.TempDir(), "state.json")
	if err := s.Save(p); err != nil {
		t.Fatal(err)
	}
	got, _ := Load(p)
	if !got.Done("training-platform", "01-a") {
		t.Fatal("not saved")
	}
}
