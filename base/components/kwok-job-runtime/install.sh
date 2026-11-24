# Lets simulated Job pods run for a while instead of completing instantly.
# KWOK's stock "pod-complete" stage moves every Running pod owned by a Job to
# Succeeded straight away. This adds a per-pod delay read from the annotation
#   pod-complete.stage.kwok.x-k8s.io/delay: "2h"     (a Go duration)
# Pods without the annotation keep the old behaviour (complete immediately).
# Requires the kwok component.
kubectl patch stage pod-complete --type=merge -p '{"spec":{"delay":{
  "durationMilliseconds": 0,
  "durationFrom": {"expressionFrom": ".metadata.annotations[\"pod-complete.stage.kwok.x-k8s.io/delay\"]"}}}}' >/dev/null
info "kwok pod-complete stage honours pod-complete.stage.kwok.x-k8s.io/delay"
