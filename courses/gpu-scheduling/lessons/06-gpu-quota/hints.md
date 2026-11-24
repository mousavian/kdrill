Quotas are per namespace. The extended-resource form only exists for
requests:

    kubectl -n team-a create quota gpu-quota --hard=requests.nvidia.com/gpu=4
    kubectl -n team-a describe quota gpu-quota

Look at `Used` vs `Hard` right after you create it.
---
Admission control (which includes quota) only checks objects when they are
*created*. The 8 sweep pods that already run stay, and team-a shows 8/4 used.
Something has to remove the extra pods. A `kubectl rollout restart` won't
help here: the new ReplicaSet can't create a single pod while the old pods
still count 8 against the quota.
---
    kubectl apply -f solution/quotas.yaml        # both quotas
    kubectl -n team-a delete pod -l app=sweep    # the ReplicaSet recreates up to the quota

`kubectl -n team-a describe rs -l app=sweep` then shows `FailedCreate ...
exceeded quota` for the other 4, and team-b's pods take the freed GPUs.
