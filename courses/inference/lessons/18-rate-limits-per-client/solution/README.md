# Solution

From the lesson directory:

    kubectl apply -f solution/limit.yaml

A **local rate limit** (a token bucket inside each Envoy) with a `Distinct` header selector: Envoy keeps one bucket
per value of `x-api-key`, each holding 2 tokens and refilling 2 per second. A request needs a token or gets
`429 Too Many Requests`. Mallory's 8 users now get through 2 requests per second (the rest are rejected immediately, which also costs the
server nothing), leaving most of the model's 2 concurrent slots for others; alice, under her own budget, sees normal latency.
Requests without the header match no rule and are not limited here.

Choosing the number: the server's capacity (2 slots x 1/0.7 s = about 2.8 requests/s in this lab) divided by the clients you
expect to be active at once, with some burst room. A bucket of N tokens lets a client send N requests *at once*.

Limits of this simple setup, and what real platforms add:

- **Local** limits are per Envoy replica (with several gateway replicas the effective rate is multiplied); **global** limits (Envoy Gateway's
  rate-limit service with Redis) are shared across replicas.
- Requests are not tokens. One request can carry a 50 000-token prompt and ask for 4000 tokens back; real LLM budgets are
  counted in **tokens** (per minute, per day), known only after the response (usage in the body). Envoy AI Gateway and
  Envoy Gateway's cost-based global rate limiting (limit values or costs from dynamic metadata set by an ext_proc) do that.
- Identify clients by authenticated identity (JWT claim, API key checked by a SecurityPolicy), not by a header the client can invent: here anybody can pick a new `x-api-key` value for a new bucket.
