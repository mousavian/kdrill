# Solution

From the lesson directory:

    kubectl apply -f solution/objectives.yaml

Two **InferenceObjectives** (API group `llm-d.ai`, version `v1`; it was `InferenceModel` in early versions of the
Gateway API Inference Extension and moved to the llm-d router project) attached to the pool:

- `chat`: priority 100 (interactive: a person is waiting);
- `batch`: priority -10 (negative = *sheddable*: nobody is waiting for it right now, a retry later is fine).

A client names its objective with the header `x-gateway-inference-objective: batch`. The picker computes how
saturated the pool is from the replicas' metrics (queue depth and KV-cache use). While at least one replica has room
nothing is dropped; when **every** replica is saturated, sheddable requests are rejected at once with
`429 system saturated, sheddable request dropped`, so the capacity that is left goes to the requests that
matter. Requests with a priority of 0 or more still reach the replicas (and may queue there).

The header is chosen by the *client*: in production the gateway sets it per route or per authenticated tenant
(a RequestHeaderModifier on an HTTPRoute, or the AI gateway's policy), and strips any client-supplied value; otherwise a
batch client can claim to be interactive.

Newer router versions add **flow control** (feature gate `flowControl`): instead of rejecting, requests wait in a queue inside the
picker and dispatch by priority and fairness, with a time-to-live that sheds what waited too long. Queueing is kinder to batch work, shedding is simpler; both
need the clients to retry with backoff.
