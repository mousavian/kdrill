# kdrill site: shared content and rules

Facts, voice and technical rules for the kdrill.5xx.tech page (toolbox
design, see `BRIEF.md`). `courses.json` (next to this file) has every
course and lesson title; embed what you need inline, the page must not
fetch it.

## What kdrill is (plain words)

kdrill is a free, open-source Kubernetes practice lab that runs on your laptop.
Each lesson hands you a small cluster that is broken or unfinished and a goal
("all 3 replicas Running, on the 2 existing nodes, each pod still requesting
1 CPU"). You fix it with your own `kubectl`. `kdrill verify` checks the cluster
and tells you exactly what is still wrong. Hints and a reference solution are
there when you are stuck; `kdrill reset` puts the lesson back.

The point: practise the outages, the pending pods and the policies that block
deploys before you meet them at work. Nothing is multiple choice; the cluster
is the exam.

## Numbers (all true as of 25 November 2026)

- 9 courses, 168 lessons live; 2 more courses planned (fine-tuning, Kubeflow).
- Runs on one small k3d (k3s) cluster sized for an 8 GB laptop. Give Docker
  about 4 GB.
- No cloud account, no cloud bill, no GPU needed.
- Fake nodes (KWOK) simulate GPU fleets and autoscaling: dozens of "H100
  nodes" cost a few MB of RAM.
- Real containers and real traffic for Envoy and Istio.
- Real tiny models: SmolLM2-135M served by llama.cpp on CPU (about 57
  tokens/s), and a 354k-parameter character-level GPT trained with PyTorch
  in 1 to 3 minutes.

## Courses (lesson counts, what kind)

| Course | Lessons | Kind | One line |
|---|---|---|---|
| k8s-scheduling | 6 | simulated nodes | Why pods go Pending: requests, taints, spread, priority, GPUs. Start here. |
| gpu-scheduling | 12 | simulated nodes | Bin-packing, time-slicing, MIG, quotas, Kueue, gang admission, DRA. |
| karpenter | 12 | simulated nodes | Real Karpenter launching fake nodes: NodePools, spot, consolidation, drift. |
| kyverno | 13 | simulated nodes | Admission policy as code: validate, mutate, generate, exceptions, CEL. |
| envoy | 38 | real traffic | Envoy from a config file to Envoy Gateway and the Gateway API. |
| istio | 14 | real traffic | Sidecars, canaries, mTLS, authorization, ambient mode. |
| inference | 26 | real model | Serve an LLM: probes, KEDA on queue depth, endpoint picking, GPU capacity. |
| training-platform | 20 | real model | Real PyTorch runs as Jobs: checkpoints, preemption, JobSet, Kueue. |
| llm-from-zero | 27 | no cluster | Build a language model yourself: data, tokenizers, hand-written backprop, a GPT. |
| fine-tuning | planned | real model | LoRA on the tiny model, eval gates, adapter serving. |
| kubeflow | planned | real model | Trainer, KServe, Katib, Pipelines. |

Dependencies (for maps or diagrams): gpu-scheduling, kyverno, envoy, istio need
k8s-scheduling; karpenter and training-platform need k8s-scheduling + gpu-scheduling; llm-from-zero needs nothing;
inference needs envoy + gpu-scheduling; fine-tuning needs llm-from-zero; kubeflow
needs training-platform + inference.

## The lesson loop (real commands and real output)

```
kdrill start k8s-scheduling/01     # sets up "Why is my pod Pending?"
kubectl get pods                   # one of 3 replicas is Pending
kubectl describe pod web-7c9f-x2k  # 0/3 nodes are available: 1 node(s) had untolerated taint, 2 Insufficient cpu.
kdrill verify
kdrill hint                        # progressive hints
kdrill solution                    # the reference answer
kdrill reset                       # start the lesson over
kdrill next                        # clean up and start the next lesson
```

Real `kdrill verify` output while the lesson is unsolved:

```
  ✓ Deployment web still asks for 3 replicas
  ✗ All 3 replicas are Running and ready
      expected: 3   got: 2
      → Look at the Pending pod: kubectl describe pod <name>, then read the Events at the bottom.
  ✓ Each pod requests at least 1 CPU (1000m)
  ✓ There are still exactly 2 worker nodes
  ✓ node-a still has 4 allocatable CPUs
  ✓ node-b still has 4 allocatable CPUs
```

After the fix every line is a ✓ and verify exits 0.

## Quick start

```
git clone https://github.com/mousavian/kdrill
cd kdrill && make build
bin/kdrill doctor        # checks docker, memory, k3d, kubectl
bin/kdrill cluster up    # one k3d cluster called "kdrill"
bin/kdrill start k8s-scheduling/01
```

Needs: Docker (Docker Desktop, OrbStack or Colima), k3d, kubectl, Go, helm.
The GitHub URL is a placeholder until the repository is public; use it as is.

## Voice

- Plain, dry, a little funny. Engineers talking to engineers. Never salesy.
- Sentence case everywhere. Buttons say what they do ("Copy the commands",
  "See all 168 lessons"). No arrows appended to buttons or links.
- No eyebrow labels in tracked capitals above headings, no "A · B · C" meta
  strings, no "WORD — fragment" labels, unless the design's concept itself
  calls for that typography (for example printed packaging or an exam paper).
- The page title is `kdrill`; the domain is kdrill.5xx.tech. The footer says
  it is open source (licence placeholder: MIT) and links to GitHub.

## Technical rules

- One self-contained `index.html`: inline CSS and JS,
  no build step. It must work when opened from disk and on GitHub Pages.
- Fonts from Google Fonts only. Scripts only from cdnjs.cloudflare.com with an
  exact pinned version (only if truly needed). No other network requests.
- All artwork is CSS, inline SVG or canvas drawn by you. No stock photos, no
  external images.
- Do not use the Kubernetes wheel logo or any other trademarked logo, and do
  not copy any real brand's trade dress (Apple/iOS UI, PagerDuty, DeWalt or
  Makita colours, the London Underground roundel or its typeface, etc.).
- Responsive from 360 px phones to wide desktops, no horizontal scroll at
  360 px.
- `prefers-reduced-motion`: show the final state of every animation, without
  the motion.
- Visible keyboard focus, real buttons and links, alt text or aria-labels on
  meaningful SVG, colour contrast at least 4.5:1 for body text.
- `<title>kdrill</title>`, a meta description, an inline SVG favicon, Open
  Graph title/description tags.
- No lorem ipsum: every section carries real content.
