# LoRA adapters as models: route to the replicas that have them loaded

Model servers: **simulator** (three replicas of one pool, two with adapters). The endpoint picker is the real llm-d router EPP.

## Concept

Fine-tuning a 70B model for each customer or task would mean one 140 GB model per customer. **LoRA** avoids it: the fine-tune is a
small set of extra weights (tens of MB) applied on top of a shared base model. A model server (vLLM, SGLang, TGI) loads the base
once and keeps several **adapters** in memory; a request selects one with the `model` field, so an adapter looks like just
another model name: `{"model": "sql-lora", ...}`.

Adapters are loaded per replica, a limited number at a time (`--max-loras`), either at start or on demand from storage.
So replicas of the same Deployment can differ in which adapters they hold, and routing has to know. A request for an adapter that
is not on the replica either fails or waits for a load (and may evict another adapter). The **endpoint picker** reads each
replica's loaded adapters from its metrics and its **`lora-affinity-scorer`** prefers the ones that have the requested adapter.

The picker is configured by an `EndpointPickerConfig`: a list of **plugins** (filters, scorers, pickers, data sources) and
**scheduling profiles** that say which plugins run with what weight; the sum of weighted scores decides.

## The situation

The pool `llm` has three Deployments: `adapter-sql` (adapter `sql-lora`), `adapter-chat` (adapter `chat-lora`), and `plain` (no adapters). All have
the base model `base-model`. The simulator is told what each replica has loaded (published in `vllm:lora_requests_info`). The gateway
already calls the picker as in lesson 15; the picker's file is the ConfigMap `epp-config` (key `plugins.yaml`). With the default
profile (queue depth and KV-cache use only) a request for `sql-lora` lands on any replica.

## Your task

Edit the picker's configuration so that:

- it declares a `lora-affinity-scorer` plugin and the default scheduling profile uses it with a weight of at least 3;
- the picker runs the new configuration (it reads its file at start);
- at least 26 of 30 requests for `sql-lora` are answered by the `adapter-sql` replica, at least 26 of 30 for `chat-lora` by
  `adapter-chat`, and requests for `base-model` work on any replica.

A scorer is a preference, not a filter. In this lab, with three requests at a time, about one request in a hundred still reaches a
replica without the adapter and gets a 404, which is why verify does not ask for 30 of 30. Without the scorer it is about two in three.

## Useful commands

    kubectl exec client -- ask -m sql-lora -n 12 -c 3 http://edge/v1/chat/completions
    kubectl get cm epp-config -o jsonpath='{.data.plugins\.yaml}'
    kubectl rollout restart deploy/epp
    kubectl logs deploy/epp | tail
    kubectl explain inferencepool.spec

When you think you're done: `kdrill verify`

## On a real cluster

vLLM: `--enable-lora --lora-modules name=path --max-loras N`, dynamic loading through `/v1/load_lora_adapter` (a controller such as
the llm-d / GIE "LoRA syncer" sidecar keeps replicas in line with a ConfigMap), and `vllm:lora_requests_info` for the picker. Combine with
prefix-cache affinity (long shared prompts) and keep the adapters' total size within GPU memory.

## Read more

- https://docs.vllm.ai/en/latest/features/lora.html
- https://github.com/llm-d/llm-d-router/tree/v1.0.0/pkg/epp/framework/plugins/scheduling/scorer/loraaffinity
- https://arxiv.org/abs/2106.09685
- https://gateway-api-inference-extension.sigs.k8s.io/
