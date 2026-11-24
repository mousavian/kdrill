Injection is switched on per namespace with a label, and it only affects
Pods created afterwards:

    kubectl get ns shop --show-labels
    kubectl -n shop get pods        # READY 1/1 = no sidecar
---
    kubectl label namespace shop istio-injection=enabled
    kubectl -n shop rollout restart deploy web api client

Before restarting `batch`, opt it out in its Pod template:
`spec.template.metadata.labels: {sidecar.istio.io/inject: "false"}`.
`kubectl -n shop edit deploy batch` or apply `solution/batch.yaml`.
---
Check the result:

    kubectl -n shop get pods         # web/api/client 2/2, batch 1/1
    istioctl proxy-status            # every sidecar SYNCED with istiod
    kubectl -n shop exec deploy/client -c curl -- curl -s api:8000/headers

The `X-Forwarded-Client-Cert` header in the last answer carries the
client's SPIFFE identity.
