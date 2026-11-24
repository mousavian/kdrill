# Solution

    kubectl delete hpa llm
    kubectl scale deploy/llm --replicas=4
    kubectl rollout status deploy/llm --timeout=120s

Why the CPU HPA did nothing: it computes `desired = ceil(replicas x currentUtilisation /
targetUtilisation)` where utilisation is CPU *usage* divided by the CPU *request*. A
model server's CPU is nearly idle while it waits for the GPU (here: for a timer), so even
with a queue of six requests the reading stayed a few percent against a 50% target, and
the HPA kept one replica. The opposite failure exists too: the real llama.cpp server
burns every CPU thread it is given from the first request, so a CPU HPA scales on
"busy", not on "queued".

While an HPA exists it owns `spec.replicas`: `kubectl scale` changes the Deployment and
the HPA changes it back within its sync period (15 s) plus stabilisation. That is also why
a KEDA ScaledObject and a hand-made HPA on the same Deployment fight each other: KEDA
creates an HPA of its own. Replacing the HPA's signal with the right one is the next lesson.

Four replicas x two slots = eight concurrent requests = the eight users: the queue empties.
