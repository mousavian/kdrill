source "$KDRILL_HOME/courses/inference/lib.sh"
# the expected answers are computed from the lesson's own inputs file, not from the cluster
I() { awk -v k="$1" '$1==k":" {gsub(/"/,"",$2); print $2}' "$KDRILL_LESSON_DIR/manifests/inputs.yaml"; }
ceil() { awk -v a="$1" -v b="$2" 'BEGIN{q=a/b; r=int(q); if (q>r) r++; print r}'; }
peak="$(I peak-requests-per-second)"; tok="$(I avg-output-tokens)"; head="$(I headroom-percent)"; z="$(I zones)"; gpr="$(I gpus-per-replica)"; gpn="$(I gpus-per-node)"; off="$(I offpeak-fraction-percent)"
need=$(( peak * tok ))                                  # generated tokens per second at peak
best=""; bestcost=999999
for g in l40s h100; do
  tps="$(I $g-tokens-per-second)"; price="$(I $g-price-per-hour)"
  usable=$(( tps * (100 - head) ))                       # tokens/s per replica x 100, after headroom
  reps=$(ceil $(( need * 100 )) $usable)
  cost=$(awk -v r="$reps" -v p="$price" 'BEGIN{printf "%d", r*p*100}')
  eval "reps_$g=$reps"
  if (( cost < bestcost )); then bestcost=$cost; best=$g; fi
done
eval "R=\$reps_$best"
RZ=$(ceil $(( R * z )) $(( z - 1 )))                    # lose one zone out of z: the others carry R replicas
GPUS=$(( RZ * gpr ))
PERZ=$(ceil "$RZ" "$z")                                  # replicas per zone, rounded up
NODES=$(( z * $(ceil $(( PERZ * gpr )) "$gpn") ))        # equal nodes per zone
MINR=$(ceil $(( R * off )) 100); (( MINR < z )) && MINR=$z   # never fewer than one per zone
MAXR=$RZ
P() { jp cm/plan "{.data.$1}"; }
echo "(inputs: ${need} tokens/s at peak; cheapest per hour: ${best})"
check_eq "plan.gpu-type: the GPU type that serves the peak at the lowest hourly cost" "$best" "$(P gpu-type)"
why "For each type: replicas = ceil(peak tokens/s / (tokens/s per replica x (100 - headroom)/100)); cost = replicas x price per hour. Compare the costs."
check_eq "plan.replicas: replicas of that type for the peak load with headroom" "$R" "$(P replicas)"
why "ceil( peak_rps x avg_output_tokens / (tokens_per_second x (1 - headroom)) )"
check_eq "plan.replicas-zone-safe: replicas so that losing one zone still leaves 'replicas' running" "$RZ" "$(P replicas-zone-safe)"
why "Each of the z zones holds 1/z of them; after losing one, (z-1)/z of the total must still equal 'replicas': total = ceil(replicas x z / (z - 1))"
check_eq "plan.nodes: GPU nodes to provision, the same number in every zone" "$NODES" "$(P nodes)"
why "replicas per zone = ceil(zone-safe / zones); nodes per zone = ceil(replicas per zone x gpus per replica / gpus per node); total = zones x that"
check_eq "plan.min-replicas: the autoscaler floor (off-peak share of 'replicas', never below one per zone)" "$MINR" "$(P min-replicas)"
check_eq "plan.max-replicas: the autoscaler ceiling (what the provisioned GPUs hold: zone-safe replicas)" "$MAXR" "$(P max-replicas)"
check "The plan is consistent: min-replicas <= replicas <= max-replicas" bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && "$3" =~ ^[0-9]+$ ]] && (( $1 <= $2 && $2 <= $3 ))' _ "$(P min-replicas)" "$(P replicas)" "$(P max-replicas)"
check_eq "The measured inputs were not edited" "$(awk '/^  [a-z0-9-]+: "/{gsub(/"/,"");print $1 $2}' "$KDRILL_LESSON_DIR/manifests/inputs.yaml" | sort | paste -sd' ' -)" \
  "$(kubectl get cm inputs -o jsonpath='{range .data}{end}' >/dev/null 2>&1; for k in $(kubectl get cm inputs -o jsonpath='{.data}' | tr ',{}' '\n\n\n' | sed -n 's/^"\([^"]*\)":.*/\1/p'); do echo "$k:$(jp cm/inputs "{.data.$k}")"; done | sort | paste -sd' ' -)"
