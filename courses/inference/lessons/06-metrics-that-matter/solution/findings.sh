#!/bin/bash
# Reads the live numbers from the running server and writes the ConfigMap `findings`.
sleep 15   # let the users settle after the restart
M() { kubectl exec client -- curl -s --max-time 5 http://llm/metrics | awk -v n="$1" '$1==n {print $2}'; }
t0="$(M llamacpp:tokens_predicted_total)"; sleep 10; t1="$(M llamacpp:tokens_predicted_total)"
tps="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%d", (b-a)/10}')"
q="$(M llamacpp:requests_deferred | awk '{printf "%d", $1}')"
kubectl create configmap findings --dry-run=client -o yaml \
  --from-literal=waiting-metric=llamacpp:requests_deferred \
  --from-literal=running-metric=llamacpp:requests_processing \
  --from-literal=tokens-metric=llamacpp:tokens_predicted_total \
  --from-literal=queue-depth="$q" --from-literal=tokens-per-second="$tps" | kubectl apply -f -
