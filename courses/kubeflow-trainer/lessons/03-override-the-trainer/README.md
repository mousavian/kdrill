# Overriding the trainer - args, env and resources

## Concept

A TrainJob changes a runtime through one block, `spec.trainer`:

| Field | What it does |
|---|---|
| `image` | replaces the image of the trainer container |
| `command` / `args` | **replace** the container's command / args (they are not appended) |
| `env` | **merged** into the container's environment (same name: the TrainJob's value wins) |
| `numNodes` | how many nodes (pods) the training runs on |
| `numProcPerNode` | processes per node for the framework policy |
| `resourcesPerNode` | requests and limits, merged over the runtime's |

Only the trainer container is touched: the replicated job that carries the ancestor label
`trainer.kubeflow.org/trainjob-ancestor-step: trainer`, container `node`. Initializers and other steps keep
what the runtime says (lesson 5). Setting a field the runtime does not expect does not fail: if you set an
environment variable that the program ignores, nothing tells you.

That is what bites here. The tiny GPT's `train` reads every option from a flag or from an environment
variable (`--steps` or `STEPS`), and a **flag beats the variable**. A runtime that fixes `--steps 1200` in its
args therefore makes a TrainJob's `STEPS` meaningless. To change what the program receives on its command line,
set `args` (all of them: the runtime's are gone).

Some variables are managed by the controller and cannot be set: with the PyTorch policy these are the
`PET_*` variables (lesson 4). And a TrainJob's `spec.trainer` is **immutable** once created: to change it, delete
the TrainJob and create a new one (you can change `spec.suspend` and, while it is suspended, runtime patches;
lesson 6 and 7).

## The situation

The platform's runtime `tiny-gpt` runs the default 1200-step training (`--steps 1200 --seed 1`). The TrainJob
`tuned` was meant to train 300 steps with seed 11 and set `STEPS=300` and `SEED=11`. It is running now, and it
trains 1200 steps with seed 1.

## Your task

Replace the TrainJob `tuned` with one that, without changing the runtime:

- trains 300 steps with seed 11 and batch size 16 (arguments to `train`);
- sets `RUN_LABEL=lesson3`; the runtime's own `OMP_NUM_THREADS=1` must survive;
- requests 500m CPU and 450Mi memory per node, with a memory limit of 1Gi;
- runs to completion.

`kdrill verify` inspects the pod the TrainJob really created: its log (300 steps, seed 11, batch size 16), its
environment (`RUN_LABEL=lesson3` and `OMP_NUM_THREADS=1`), its requests and limits, its image and command (still
the runtime's), that the platform's runtime is unchanged and that the JobSet belongs to the TrainJob. The
run takes about 15-20 s.

## Useful commands

    kubectl get trainjob,jobset,pods
    kubectl get pod -l jobset.sigs.k8s.io/jobset-name=tuned -o jsonpath='{.items[0].spec.containers[0]}' ; echo
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=tuned | head
    kubectl explain trainjob.spec.trainer
    kubectl delete trainjob tuned

## On a real cluster

Teams usually keep `command` in the runtime (the launcher: `torchrun`, `mpirun`) and let users set only `args`
or the training script; the Kubeflow SDK's `CustomTrainer` does that by turning a Python function into the
container's command. `resourcesPerNode` is where GPU requests go (`nvidia.com/gpu: 8`), and with the PyTorch
policy the controller reads them to decide how many processes `torchrun` starts per node. Because a TrainJob
is immutable, platform tooling usually generates a new TrainJob name for every run.

## Read more

- https://www.kubeflow.org/docs/components/trainer/user-guides/pytorch/
- https://pkg.go.dev/github.com/kubeflow/trainer/v2/pkg/apis/trainer/v1alpha1
- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
