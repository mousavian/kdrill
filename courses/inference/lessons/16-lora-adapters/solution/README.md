# Solution

From the lesson directory:

    kubectl apply -f solution/epp-config.yaml
    kubectl rollout restart deploy/epp
    kubectl rollout status deploy/epp --timeout=90s

The picker's configuration gains a `lora-affinity-scorer` plugin, referenced from the default scheduling profile with
weight 10 (next to `queue-scorer` and `kv-cache-utilization-scorer`, weight 2 each).

**LoRA** (low-rank adaptation) fine-tunes a model by training small extra matrices (megabytes, not gigabytes). A server can keep
one base model in GPU memory and load many adapters on top, and a request chooses one by putting the adapter's name in the `model`
field: the adapter *is* a model name. Each replica holds a limited set of adapters (`--max-loras`), loaded from storage on demand
(seconds) or at start. vLLM exposes what a replica has in `vllm:lora_requests_info` (running and waiting adapters, `max_lora`).

Without adapter awareness the picker only balances load, so a request for `sql-lora` could land on a replica that never loaded it
(404 here; on real vLLM a slow on-demand load or an error). The scorer gives each candidate 1.0 if the adapter is already active, 0.8 when it
could still load it (free adapter slot) and 0 when it is full; weight 10 makes that outweigh queue and cache differences, while
requests for the base model are unaffected (every replica scores the same).

Routing by adapter name is also how you roll out a new fine-tune (a new adapter name on a few replicas) without a new Deployment.
