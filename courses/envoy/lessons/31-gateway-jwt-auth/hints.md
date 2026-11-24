Authentication and authorization for a route are one SecurityPolicy:

    kubectl explain securitypolicy.spec.jwt.providers
    kubectl explain securitypolicy.spec.authorization.rules

The public keys are in the ConfigMap `jwks` (key `jwks`); a provider can
read them with `localJWKS: {type: ValueRef, valueRef: {group: "", kind: ConfigMap, name: jwks}}`.
---
    jwt:
      providers:
      - name: lab
        issuer: https://auth.lab
        audiences: [shop]
        localJWKS: {type: ValueRef, valueRef: {group: "", kind: ConfigMap, name: jwks}}
        claimToHeaders: [{claim: sub, header: x-user}]
    authorization:
      defaultAction: Deny
      rules:
      - action: Allow
        operation: {methods: [GET, HEAD]}
        principal: {jwt: {provider: lab, claims: [{name: iss, values: ["https://auth.lab"]}]}}
      - action: Allow
        principal: {jwt: {provider: lab, claims: [{name: role, values: [admin]}]}}
---
    kubectl apply -f solution/security.yaml      # from the lesson directory
