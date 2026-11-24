Reproduce both problems from `web`:

    kubectl -n shop exec deploy/web -c curl -- curl -s -o /dev/null -w '%{http_code} %{time_total}\n' inventory:8000/delay/5
    kubectl -n shop exec deploy/web -c curl -- sh -c 'for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code} " "inventory:8000/unstable?failure_rate=0.4"; done; echo'

Both are fixed in the VirtualService route, next to `route:`:
`kubectl explain virtualservice.spec.http.timeout` and `.retries`.
---
    timeout: 2s
    retries:
      attempts: 3
      retryOn: 5xx,connect-failure,reset

`perTryTimeout` is optional; if you set it, keep it above 1 s or the 1 s
request fails.
---
    kubectl apply -f solution/virtualservice.yaml
    kubectl -n shop exec deploy/web -c curl -- curl -s inventory:8000/headers | grep -A2 Attempt
