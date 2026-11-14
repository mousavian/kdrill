# Solution

From the lesson directory:

    kubectl apply -f solution/sites.yaml

| Site | Symptom | Evidence | Bug | Fix |
|---|---|---|---|---|
| www.lab | 404 | route `Accepted: False`, `NoMatchingParent` | `sectionName: https`, no such listener | `sectionName: http` (FIX 1) |
| api.lab | 500 | `ResolvedRefs: False` (port not found), Envoy answers with a direct 500 | backendRef port 8080, Service has 80 | port 80 (FIX 2) |
| pay.lab | 500 | `ResolvedRefs: False`, `RefNotPermitted` | cross-namespace backendRef without permission | ReferenceGrant in `payments` (FIX 3) |
| reports.lab | 503 `no healthy upstream` | access log flag `UH`; `/clusters` has no host for the reports cluster; EndpointSlice empty | Service selects `app: report` | `app: reports` (FIX 4) |
| checkout.lab | 503 `no healthy upstream` | flag `UH`; `/clusters` shows the host with `/failed_active_hc`; `health_check.failure` grows | health check expects 204, `/health` answers 200 | `expectedStatuses: [200]` (FIX 5) |

The method, which works for any Envoy, Gateway or mesh:
1. **Status first.** Accepted / Programmed / ResolvedRefs with reasons
   catch most configuration mistakes before any traffic flows.
2. **Envoy's own answer.** 404 empty = no route; 500 from Envoy Gateway =
   invalid backend; 503 + `UH` = no usable host; 503 + `UF` = can't connect;
   504 + `UT` = timeout; 429 + `RL`, 403 RBAC, 401 jwt.
3. **The admin interface** tells you *why* a cluster has no usable host:
   no host at all (discovery: Service selector, EndpointSlices, ports) or
   hosts flagged unhealthy (health checks, outlier detection).
4. Fix the config at its source: the route, the Service, the policy, the
   grant. Not the workload, and not with catch-alls.
