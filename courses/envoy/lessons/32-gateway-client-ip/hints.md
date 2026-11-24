See what Envoy believes the client address is:

    kubectl exec client -- curl -s http://edge/ -H 'Host: www.lab' -H 'X-Forwarded-For: 203.0.113.7' >/dev/null
    kubectl logs deploy/edge -c envoy --tail=1      # downstream_remote_address

By default that's the peer of the TCP connection (the client pod, standing
in for the load balancer), whatever the XFF header says.
---
- ClientTrafficPolicy on the Gateway:
  `clientIPDetection: {xForwardedFor: {numTrustedHops: 1}}`.
- SecurityPolicy on the HTTPRoute `admin`:
  `authorization: {defaultAction: Deny, rules: [{action: Allow, principal: {clientCIDRs: ["203.0.113.0/24"]}}]}`.
---
    kubectl apply -f solution/policies.yaml      # from the lesson directory
