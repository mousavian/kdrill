Try the probes yourself and read the answers:

    kubectl create --dry-run=server -f probes/untagged.yaml
    kubectl create --dry-run=server -f probes/init-latest.yaml
    kubectl create --dry-run=server -f probes/dockerhub.yaml

Field reference: `kubectl explain clusterpolicy.spec.rules.validate.deny`.
---
`disallow-latest`: a value can combine conditions with `&` (and `|`):
`"*:* & !*:latest"`. A pattern only checks fields it names; add
`=(initContainers):` (the `=( )` anchor means "only if present").

`restrict-registries`: a `deny` rule with a condition. The key
`{{ request.object.spec.[initContainers, containers][][].image }}` is the list of
all images; the operator `AnyNotIn` with values `["registry.acme.io/*",
"ghcr.io/acme/*"]` is true when any image is from somewhere else. Use the same
`{{ ... }}` in the message.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory

See `kdrill solution` for why each piece is needed.
