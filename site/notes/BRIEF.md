# kdrill.5xx.tech: the chosen design direction

The toolbox direction was chosen over four others (3:14 AM phone, exam
paper, network map, ball pit), which were dropped. The built page is
`../index.html`. Shared facts, voice and technical rules: `CONTENT.md`.
Lesson data: `courses.json`.

---

## 1-toolbox: the kdrill K-8 cordless cluster drill

**Idea.** The website is the retail box and instruction leaflet of a power tool
called kdrill. Lessons are drill bits. Funny because it is played completely
straight.

**Palette.**
- kraft cardboard `#C8A27A` (page base; corrugation from a faint
  repeating-linear-gradient plus an SVG feTurbulence grain at low opacity)
- flexo print ink `#1D2A5B` (all printed text and line art: one-ink print)
- signal orange `#FF5A1F` (the tool body only, and the one call to action)
- sticker yellow `#FFD23F` (stickers and warning labels only)
- bit steel `#8A8F98` and `#D9DDE3`; case plastic `#2E3238`

**Type.** Box print: Big Shoulders Stencil Display (800-900), stencilled like
ink sprayed through a template. Body and spec tables: Archivo (variable; use the
width axis: wide 125 for spec headings, 100 for body). Commands: Martian Mono.
Capitals are fine on box print because that is how packaging is printed; body
copy stays sentence case.

**Layout.**
```
+--------------------------------------------------------------+
| tape strip across the corner                    [141 BITS]   |
|  KDRILL                       ___________                    |
|  K-8 cordless cluster drill  |  drill SVG |==bit>            |
|  Breaks Kubernetes on your   |  orange    |                  |
|  laptop, on purpose.          \__[8 GB]__/                   |
|  [Get it on GitHub]  [See the bit set]                       |
+--------------------------------------------------------------+
|        the bit bores a hole through this panel:              |
|        ( torn cardboard edge )  inside: dark, live terminal  |
|        showing kdrill verify going from ✗ to ✓               |
+--------------------------------------------------------------+
| What's in the box: exploded parts diagram of one lesson,     |
| navy line art, reference numbers 1-6 with leader lines       |
+--------------------------------------------------------------+
| The bit set: moulded dark case, 8 bits + 2 empty slots       |
+--------------------------------------------------------------+
| Specifications (back-of-box table) + warning sticker         |
| Instruction leaflet: folded white paper, quick start         |
| Footer: generated barcode, own recycling-style mark          |
+--------------------------------------------------------------+
```
Left-aligned text, the product art on the right on desktop, stacked on mobile.

**Signature moment: the drill bores through the page.** Scroll-driven: as the
hero scrolls up, the bit spins (stripe pattern rotating) and advances into the
next panel; a hole with a jagged, torn-cardboard edge (SVG mask) opens there and
grows, revealing a dark "inside" where a terminal plays `kdrill verify` (first
with a ✗ and the hint, then all ✓). A few cardboard flecks fall only while the
user is scrolling. Reduced motion: the hole is already open, terminal shows the
final state.

**Sections and copy.**
- Hero: "Cordless cluster drill. Breaks Kubernetes on your laptop, on purpose."
  Burst sticker "141 bits included". Battery pack labelled "8 GB".
- What's in the box: an exploded parts diagram of a lesson. Reference numbers
  are legitimate here (parts diagrams use them): 1 a broken cluster, 2 a goal,
  3 your own kubectl, 4 verify, 5 progressive hints, 6 a reset button.
- The bit set: moulded case with 8 bits whose length and diameter grow with the
  lesson count (envoy is the long one), each engraved with the course name and
  count; 2 empty moulded slots for fine-tuning and kubeflow ("not in this box
  yet"). Clicking or pressing a bit lifts it out and shows a spec card: course
  title, kind (simulated nodes / real traffic / real model), the lesson list
  (scrollable), and `kdrill start <course>/01` with a copy button.
- Specifications, like the back of a box: power source your laptop; memory
  8 GB (give Docker 4); cloud bill $0.00; GPUs required 0 (simulated: as many as
  you like); lessons 141; courses 8, 2 more planned; verify exits 0 when you are
  done. Own pictograms (no cloud, 8 GB, kubectl only).
- Warning sticker: "Caution: will break your cluster. `kdrill reset` puts it
  back."
- Instruction leaflet: a folded white paper sheet (fold shadows) with the quick
  start commands and a copy button.
- Footer: an SVG barcode generated from "kdrill.5xx.tech", "Made in a terminal",
  MIT, GitHub link.

---

## Why it spreads

People share what makes them look clever or in the know, what they feel
strongly about (amusement, surprise, recognition), what they took part in,
and what is useful. The page builds that in deliberately:

- **Hook in 3 seconds**, without scrolling: something recognisable or moving.
- **One screenshot moment**: the hero must make sense as a cropped screenshot
  with no context, with "kdrill" and "kdrill.5xx.tech" inside the frame.
- **Recognition and identity**: in-jokes platform, SRE and ML-infra engineers
  live through (Pending pods, 3 AM pages, policies that block deploys). Never
  explain the joke.
- **Participation with a personal outcome**: the visitor does something and
  gets a result that is theirs (a time, a name, a progress count) and worth
  posting.
- **One hidden delight** for people who poke around. Discoveries get shared.
- **Quotable lines**: two or three short lines that work as a post on their own.
- **Clearly useful within one screen**: free, open source, runs on your laptop,
  141 lessons. The joke gets the click; the usefulness gets the share.
- **One share element**: `navigator.share` where available, otherwise copy link
  plus X, Bluesky, LinkedIn and Hacker News intent links, with prewritten text
  in the design's voice. Plain links: nothing loads from those sites.
- **Not allowed**: fake social proof (invented star counts, testimonials,
  "10,000 engineers"), dark patterns, autoplaying sound.

For the toolbox:

| Draft | Participation, personal outcome | Hidden delight | Share text idea |
|---|---|---|---|
| 1-toolbox | Click and hold the drill's trigger: it revs up (spin, rising shake) and drills to the next section; release reads out the "torque" | Hover or focus the barcode: a red scanner line passes and the price reads $0.00 | "Found a power tool for Kubernetes. 141 bits, breaks your cluster on purpose, $0." |
