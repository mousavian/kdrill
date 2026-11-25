# Course build queue

The scheduled course builder (and anyone building a course from a `BUILD.md`)
takes the **first** course in this list that still has a `BUILD.md`, builds
only that one, then removes it from this list in the same commit.

1. `kubeflow` — Kubeflow projects as separate small courses.

Built courses have no `BUILD.md` and are not listed here.
