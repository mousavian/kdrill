source "$KDRILL_HOME/courses/envoy/lib.sh"
envoy_settle
check "Envoy is running and ready (1 pod)" envoy_ready
why "kubectl logs deploy/envoy: a bad bootstrap stops Envoy at start; a bad lds/cds file is rejected and logged while Envoy keeps the old config."

echo "where the configuration comes from (admin /config_dump)"
dump="$(admin /config_dump | tr -d ' \n')"
check "No static listeners or clusters in the bootstrap" eval '! printf "%s" "$(admin "/config_dump?resource=static_listeners")$(admin "/config_dump?resource=static_clusters")" | grep -q "\"name\""'
why "Move them out of static_resources: dynamic_resources.lds_config / cds_config with a path_config_source."
dl="$(admin '/config_dump?resource=dynamic_listeners' | tr -d ' \n')"
check "Listener main comes from LDS (dynamic_listeners)" eval '[[ "$dl" == *"\"name\":\"main\""* ]]'
dc="$(admin '/config_dump?resource=dynamic_active_clusters' | tr -d ' \n')"
for c in echo-v1 echo-v2; do
  check "Cluster $c comes from CDS (dynamic_active_clusters)" eval '[[ "$dc" == *"\"name\":\"$c\""* ]]'
done

echo "behaviour"
out="$(hits_out -n 5 http://envoy:10000/shop)"
check_eq "/shop -> v1 (5 of 5)" 5 "$(count_of "200 v1" "$out")"
out="$(hits_out -n 5 http://envoy:10000/v2/shop)"
check_eq "/v2/shop -> v2 (5 of 5)" 5 "$(count_of "200 v2" "$out")"
why "A route for /v2/ in lds.yaml and a cluster echo-v2 in cds.yaml (kubelet takes up to a minute to update the mounted files)."

echo "added while running"
iso_epoch() { date -u -j -f '%Y-%m-%dT%H:%M:%S' "${1%%.*}" +%s 2>/dev/null || date -u -d "${1%%.*}" +%s 2>/dev/null; }
v2at="$(admin '/config_dump?resource=dynamic_active_clusters&name_regex=^echo-v2$' | tr -d ' \n' | grep -o '"last_updated":"[^"]*"' | head -n 1 | cut -d'"' -f4)"
up="$(admin /server_info | tr -d ' \n' | grep -o '"uptime_current_epoch":"[0-9]*s"' | grep -o '[0-9]*')"
a="$(iso_epoch "$v2at")"; b=""; [[ -n "$up" ]] && b=$(( $(date -u +%s) - up ))
gap=$(( ${a:-0} - ${b:-0} ))
check "Cluster echo-v2 was added at least 5 s after Envoy started (gap: ${gap}s)" test -n "$a" -a -n "$b" -a "$gap" -ge 5
why "Start Envoy with dynamic resources first (v1 only), then add echo-v2 to the files while it runs. A restart reloads everything at start."
