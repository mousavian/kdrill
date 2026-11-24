# First completion: a model server behind a Service

Model server: **real** (llama.cpp on CPU, SmolLM2-135M, 4-bit).

## Concept

A model server is an ordinary HTTP server with an unusual start-up: it has to
read a large file of weights into memory before it can answer anything. Most
open-source servers (vLLM, TGI, llama.cpp, Ollama) speak the same dialect, the
**OpenAI-compatible API**: `POST /v1/chat/completions` takes
`{"model": ..., "messages": [...], "max_tokens": N}` and returns the generated
message plus a `usage` block counting prompt and completion tokens. Because the
API is shared, a client, a gateway or an autoscaler does not care which engine
is behind it; this course uses that on purpose.

On Kubernetes the server is a plain Deployment and Service, so the usual
failure modes apply, with two twists. First, the weights are not in the
container image: they are a separate multi-gigabyte artifact that has to be
mounted, and a wrong path makes the server exit at start (the next lesson is
about getting weights to the pod). Second, the port matters twice: the Service's
`targetPort` must match the port the *server* really binds, which is set by a
flag or an environment variable, not by `containerPort` (that field is only
documentation, plus a name you can refer to).

llama.cpp's server is small enough to run here for real: the 135M-parameter
model is 105 MB, answers in under a second on CPU, and prints its settings and
the address it listens on when it starts. Use its log as your first debugging
tool.

## The situation

Namespace `lab` has a client pod (curl plus the helper `ask`), a Deployment
`llm` and a Service `llm`. The weights are on the node in
`/var/lib/kdrill/models`, mounted into the pod at `/models` (read-only). The pod
is crash-looping and, once it runs, the Service would not reach it either.

## Your task

- Deployment `llm` runs one ready replica of the **same** llama.cpp image;
- Service `llm` has a ready endpoint;
- `GET http://llm/health` answers ok, and `POST http://llm/v1/chat/completions`
  (model `tiny`, `max_tokens` 8) returns 200 with a non-empty assistant message,
  between 1 and 8 completion tokens, and llama.cpp's `timings` block.

## Useful commands

    kubectl get pods
    kubectl logs deploy/llm
    kubectl get endpointslices -l kubernetes.io/service-name=llm
    kubectl exec client -- ask -v -p "Say hello." http://llm/v1/chat/completions
    kubectl exec client -- curl -s http://llm/props | head -c 300

`ask` sends chat completions: `ask -h` lists its options (`-n` count, `-c`
concurrency, `-s` streaming, `-t` max tokens). When you think you're done:
`kdrill verify` (the first start pulls the server image, about 100 MB).

## On a real cluster

vLLM listens on 8000 by default and TGI on 80, so a Service copied from one
engine to another is a classic mistake. Real weights are tens of gigabytes
(a 70B model in 16-bit is about 140 GB) and the pod usually needs a GPU:
`resources.limits: {nvidia.com/gpu: 1}` and a node that has one. The lab model
is 1000 times smaller so that it fits next to the rest of the cluster.

## Read more

- https://github.com/ggml-org/llama.cpp/tree/master/tools/server
- https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html
- https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service
- https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF
