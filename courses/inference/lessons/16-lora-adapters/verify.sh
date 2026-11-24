source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
U=http://edge/v1/chat/completions
cfg="$(jp cm/epp-config '{.data.plugins\.yaml}')"
check "The picker's configuration lists a lora-affinity-scorer plugin" bash -c '[[ "$1" == *"type: lora-affinity-scorer"* ]]' _ "$cfg"
why "kubectl edit cm epp-config; plugins: - type: lora-affinity-scorer ... then the scheduling profile must reference it."
check "... and the default scheduling profile uses it with a weight of at least 3" \
  bash -c 'echo "$1" | awk "/pluginRef: lora-affinity/{f=1;next} f&&/weight:/{print \$2; exit}" | { read w; [[ "$w" =~ ^[0-9.]+$ ]] && awk -v w="$w" "BEGIN{exit !(w>=3)}"; }' _ "$cfg"
why "A scorer only counts if a profile has a pluginRef entry for it; its weight must outweigh the load scorers (2 and 2) when an adapter is missing."
check_eq "The picker was restarted after the change (it reads its configuration at start)" 1 "$(ready_pods app=epp)"
_probe() { epp_active $U base-model; }
(( _KD_FAIL == 0 )) && { gw_wait_config edge dynamic_active_clusters override_host 45 || true; wait_until 30 _probe || true; }   # the endpoint-override cluster needs ~15 s to warm
_warm() { local o; o="$(ask_out -m sql-lora -n 6 -c 3 -t 2 -w 3 $U)"; [[ "$(count_matching '^200 ' "$o")" == 6 ]]; }
(( _KD_FAIL == 0 )) && { wait_until 30 _warm || true; }   # a freshly started picker needs a moment to scrape every replica
s="$(ask_out -m sql-lora -n 30 -c 3 -t 4 -w 6 $U)"
c="$(ask_out -m chat-lora -n 30 -c 3 -t 4 -w 6 $U)"
b="$(ask_out -m base-model -n 12 -c 3 -t 4 -w 6 $U)"
echo "sql-lora: $(printf '%s' "$s" | tr '\n' ';')"
ns="$(count_matching '^200 adapter-sql-' "$s")"; nc="$(count_matching '^200 adapter-chat-' "$c")"
echo "chat-lora: $(printf '%s' "$c" | tr '\n' ';')"
check_ge "At least 26 of 30 requests for sql-lora answered 200 by the adapter-sql replica (got $ns)" 26 "$ns"
why "The other replicas answer 404 'model sql-lora does not exist': they never loaded that adapter."
check_ge "At least 26 of 30 requests for chat-lora answered 200 by the adapter-chat replica (got $nc)" 26 "$nc"
why "Without the scorer about 10 of 30 get there. A scorer is a preference, not a filter: under concurrent load the odd request still lands elsewhere."
check_eq "12 of 12 requests for the base model answered 200 (any replica)" 12 "$(count_matching '^200 ' "$b")"
check_eq "The Service still selects all three Deployments' pods (pool=llm, 3 ready): no shortcuts" "llm 3" "$(jp svc/llm '{.spec.selector.pool}') $(ready_pods pool=llm)"
