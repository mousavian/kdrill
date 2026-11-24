source "$KDRILL_HOME/courses/inference/lib.sh"
C='{.spec.template.spec.containers[0]'
sp="$(jp deploy/llm "$C.startupProbe.httpGet.path}")"
ft="$(jp deploy/llm "$C.startupProbe.failureThreshold}")"; per="$(jp deploy/llm "$C.startupProbe.periodSeconds}")"
budget=0; [[ -n "$sp" ]] && budget=$(( ${ft:-3} * ${per:-10} ))
lp="$(jp deploy/llm "$C.livenessProbe.httpGet.path}")"
rp="$(jp deploy/llm "$C.readinessProbe.httpGet.path}")"
check_eq "startupProbe: httpGet on /health/ready (it only passes once the model is loaded)" /health/ready "$sp"
why "A startup probe disables liveness and readiness until it succeeds, so slow loading is not mistaken for a hang."
check_ge "... and it allows at least 30 s to load (failureThreshold x periodSeconds = ${budget}s)" 30 "$budget"
why "Model loading time grows with the model: allow generously; a startup probe costs nothing once it has passed."
check "livenessProbe does not use /health/ready (a server that is busy or still loading is not hung)" bash -c '[[ -n "$1" && "$1" != /health/ready ]]' _ "$lp"
why "Liveness answers 'is the process stuck?' (restart it). Use /health, which answers as soon as the server runs."
check_eq "readinessProbe: httpGet on /health/ready (not just an open port)" /health/ready "$rp"
why "Readiness answers 'may it receive traffic?'. tcpSocket says yes as soon as the port is open, before the model is loaded."
settle llm 60 || true
h="$(current_hash llm)"
sel="app=llm,pod-template-hash=$h"
check_eq "Both replicas of the current ReplicaSet are ready" 2 "$(ready_pods "$sel")"
why "kubectl get pods; kubectl describe pod <name> shows the probe failures."
check_eq "No container has been restarted (nothing killed a server while it was loading)" 0 "$(restarts "$sel")"
# behaviour: how long did a pod take from container start to Ready?
slow=0
for p in $(pod_names "$sel"); do
  st="$(jp "pod/$p" '{.status.containerStatuses[0].state.running.startedAt}')"
  rd="$(jp "pod/$p" '{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')"
  [[ -n "$st" && -n "$rd" ]] || continue
  d=$(( $(date -u -j -f %Y-%m-%dT%H:%M:%SZ "$rd" +%s 2>/dev/null || date -u -d "$rd" +%s) - $(date -u -j -f %Y-%m-%dT%H:%M:%SZ "$st" +%s 2>/dev/null || date -u -d "$st" +%s) ))
  (( d >= 12 )) && slow=$((slow+1))
done
check_eq "Each pod became Ready only after the model had loaded (>= 12 s after its container started)" 2 "$slow"
why "A pod that is Ready after 2 s was declared ready by an open port, not by the model."
check_eq "Service llm has 2 ready endpoints" 2 "$(svc_endpoints llm)"
check "A completion through the Service answers 200" chat_ok http://llm/v1/chat/completions
