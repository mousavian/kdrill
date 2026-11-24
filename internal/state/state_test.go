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
