# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

| Site | Symptom | Evidence in the admin interface | Bug | Fix |
|---|---|---|---|---|
| shop.lab | 503 `upstream connect error ... connection timeout` | `/clusters`: host `10.43.x.x:8080`; `/stats`: `cluster.shop.upstream_cx_connect_fail` grows | cluster port 8080, the Service listens on 80 | `port_value: 80` |
| catalog.lab | 503 `no healthy upstream` | `/clusters`: no host lines for catalog; `cluster.catalog.membership_total: 0` | DNS name `catalogue` does not exist | `address: catalog` |
| api.lab | 404, empty body | `http.ingress.no_route` grows; `/config_dump`: `match: {path: "/"}` | `path` is an exact match | `prefix: "/"` |

Notes:
- Envoy answers for a broken upstream itself, with `server: envoy` and a short
  body. The access log (lesson 14) records the same thing as a response
  flag: `UF` (upstream connection failure), `UH` (no healthy upstream), `NR`
  (no route).
- `/clusters` shows what Envoy resolved and how each host is doing
  (`cx_active`, `rq_total`, `rq_error`, `health_flags`). `/config_dump` is the
  config Envoy runs, which is not necessarily the file you think you gave it.
  `/stats` are counters per listener, HCM (`http.<stat_prefix>.*`) and
  cluster (`cluster.<name>.*`). `/stats/prometheus` is the same for scraping.
- A STRICT_DNS cluster whose name doesn't resolve isn't an error at start:
  Envoy starts, keeps retrying the lookup, and the cluster just has no hosts.

Takeaways: reproduce with curl, read Envoy's own answer, then compare
`/clusters` and `/config_dump` with what you expected.
