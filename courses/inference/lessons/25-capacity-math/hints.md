    kubectl get cm inputs -o yaml

Do it per GPU type first. Usable tokens/s per replica = tokens_per_second x (100 - headroom) / 100. Replicas for the peak =
ceil(peak requests/s x average output tokens / usable). Cost per hour = replicas x price. Take the cheaper type.
---
For the chosen type (R = replicas for the peak):
- zone-safe total = ceil(R x zones / (zones - 1));
- replicas per zone = ceil(zone-safe / zones); nodes per zone = ceil(replicas per zone x gpus-per-replica / gpus-per-node); nodes = zones x that;
- min = ceil(R x offpeak / 100) but at least one replica per zone; max = zone-safe.
---
    kubectl apply -f solution/plan.yaml      # from the lesson directory
