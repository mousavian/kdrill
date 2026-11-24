An HTTPS listener on the Gateway:

    - name: https-shop
      protocol: HTTPS
      port: 443
      hostname: shop.lab
      tls:
        mode: Terminate
        certificateRefs: [{kind: Secret, name: shop-tls}]

Two listeners can share port 443 if their hostnames differ: Envoy picks the
certificate by SNI. Test with
`kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to shop.lab:443:edge:443 https://shop.lab/`.
---
- Attach `shop` and `api` to their HTTPS listeners only:
  `parentRefs: [{name: edge, sectionName: https-shop}]`.
- A route `to-https` on `sectionName: http` for both hostnames with a
  `RequestRedirect` filter (`scheme: https`, `statusCode: 301`).
- `ClientTrafficPolicy` with `targetRefs` to the Gateway and
  `tls: {minVersion: "1.3"}`.
---
    kubectl apply -f solution/edge.yaml      # from the lesson directory
