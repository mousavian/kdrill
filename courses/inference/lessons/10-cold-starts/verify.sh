source "$KDRILL_HOME/courses/inference/lib.sh"
C='{.spec.template.spec.containers[0]'
S='{.spec'
min="$(jp scaledobject/llm "$S.minReplicaCount}")"
check "The ScaledObject keeps a warm replica: minReplicaCount >= 1 (got ${min:-?})" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 ]]' _ "${min:-x}"
why "With 0 replicas nothing is listening: KEDA's metrics-api trigger sees no demand until a request has already failed. Waking a server from the first request needs an activator/interceptor in front (KEDA HTTP add-on, Knative, KServe)."
check_eq "Pods use imagePullPolicy IfNotPresent (the node already has the image; Always asks the registry on every start)" IfNotPresent "$(jp deploy/llm "$C.imagePullPolicy}")"
sp="$(jp deploy/llm "$C.startupProbe.periodSeconds}")"
check "The startupProbe polls every 2 s or faster (got ${sp:-?} s): readiness is noticed within seconds of the load finishing" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -le 2 ]]' _ "${sp:-x}"
why "A 10 s probe period can add up to 10 s after the model is ready, for every replica, on every scale-up."
check "The model load time is unchanged (--startup-duration 20s): it is the part you cannot remove" bash -c '[[ "$1" == *"--startup-duration 20s"* ]]' _ "$(jp deploy/llm "$C.args[*]}")"
_ready() { [[ "$(ready_pods app=llm)" -ge 1 ]]; }
[[ "$min" =~ ^[0-9]+$ && "$min" -ge 1 ]] && { wait_until 75 _ready || true; }
check_ge "At least one replica is ready (ready: $(ready_pods app=llm))" 1 "$(ready_pods app=llm)"
out="$(ask_out -n 3 -t 8 http://llm/v1/chat/completions)"
check_eq "Three requests sent right now all answer 200" 3 "$(count_matching '^200 ' "$out")"
# time from creation to Ready of every ready pod of the current ReplicaSet
h="$(current_hash llm)"; worst=0; seen=0
for p in $(pod_names "app=llm,pod-template-hash=$h"); do
  cr="$(jp "pod/$p" '{.metadata.creationTimestamp}')"; rd="$(jp "pod/$p" '{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')"
  [[ -n "$cr" && -n "$rd" ]] || continue
  ep() { date -u -j -f %Y-%m-%dT%H:%M:%SZ "$1" +%s 2>/dev/null || date -u -d "$1" +%s; }
  d=$(( $(ep "$rd") - $(ep "$cr") )); seen=$((seen+1)); (( d > worst )) && worst=$d
done
check "A new replica is ready within 28 s of being created (slowest ready pod: ${worst}s; the load itself is 20 s)" bash -c '[[ "$2" -ge 1 && "$1" -le 28 ]]' _ "$worst" "$seen"
why "kubectl get pod -o wide; kubectl describe pod | grep -A12 Events: look for 'Pulling image' and for the gap between 'Started' and Ready."
