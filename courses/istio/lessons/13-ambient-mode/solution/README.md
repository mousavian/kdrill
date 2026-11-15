# Solution

    kubectl apply -f solution/ambient.yaml

Or step by step:

    kubectl label namespace mall istio.io/dataplane-mode=ambient
    istioctl waypoint apply -n mall --enroll-namespace --wait
    kubectl apply -f solution/ambient.yaml      # the AuthorizationPolicy part

What happened:

1. `istio.io/dataplane-mode=ambient`: the istio-cni agent set up
   redirection inside each running Pod's network namespace (annotation
   `ambient.istio.io/redirection: enabled`) and ztunnel started serving
   them. `istioctl ztunnel-config workloads` lists them with protocol
   `HBONE`. The Pods were not restarted and still have one container.
2. `Gateway waypoint` (class `istio-waypoint`, HBONE listener on 15008):
   istiod deployed `deploy/waypoint`, an Envoy.
3. `istio.io/use-waypoint: waypoint` on the namespace: traffic to `mall`'s
   Services now passes the waypoint, which adds HTTP processing (hence
   `x-envoy-upstream-service-time`).
4. `AuthorizationPolicy api-access` with `targetRefs` to Service `api`:
   enforced by the waypoint, so `methods: [GET]` works. `bot` and web's
   POST get `403 RBAC: access denied` from the waypoint.

Takeaways:
- ztunnel = L4 + mTLS for every enrolled Pod; waypoint = opt-in L7.
- Enrolling is a namespace label, no restart.
- Attach L7 policy to the Service or waypoint (`targetRefs`), L4 policy
  with a selector.
