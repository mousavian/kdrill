# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml

`loadBalancer.type: LeastRequest` replaces `RoundRobin`. Envoy's least-request policy
picks two backends at random and sends the request to the one with fewer requests in flight
("power of two choices"). A slow backend finishes requests slowly, so it always has more
in flight, loses most of the comparisons, and receives far fewer requests than a third:
about a tenth here. No configuration says "this one is slow": the policy discovers it
from the load itself.

Why round-robin hurts model servers in particular: request cost varies by orders of magnitude
(a 50-token prompt vs a 20 000-token one, a 10-token answer vs 2000 tokens), servers keep state
(KV cache, adapters), and one replica often degrades (a thermally throttled GPU, a long
prompt in front of its queue). Counting requests in flight is the cheapest state-aware
improvement; reading the server's own queue and cache metrics (lesson 15) is the real one.

Envoy Gateway's default is LeastRequest already; the starting state set RoundRobin explicitly, as a
copy-pasted default from a stateless web service would.
