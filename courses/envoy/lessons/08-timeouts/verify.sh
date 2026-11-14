source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

# timed URL -> "STATUS SECONDS(rounded to 0.1)"
timed() { kx curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time 20 "$1" | awk '{printf "%s %.1f", $1, $2}'; }

echo "behaviour (the echo backends wait before answering when asked: ?wait=DURATION)"
check_eq "/api/items?wait=200ms -> 200" 200 "$(http_code 'http://envoy:10000/api/items?wait=200ms')"
r="$(timed 'http://envoy:10000/api/items?wait=3s')"
check_eq "/api/items?wait=3s -> 504 from Envoy" 504 "${r% *}"
why "route.timeout on the /api/ route (default 15s)."
check "... and it gave up after about 1 s (took ${r#* }s)" awk -v t="${r#* }" 'BEGIN{exit !(t>=0.8 && t<=1.8)}'
check_ge "cluster.api.upstream_rq_timeout counted it" 1 "$(stat cluster.api.upstream_rq_timeout)"
r="$(timed 'http://envoy:10000/reports/daily?wait=3s')"
check_eq "/reports/daily?wait=3s -> 200 (slow but allowed)" 200 "${r% *}"
why "Don't put a short timeout on everything: reports may take up to 10 s."
echo "configuration"
rt="$(admin '/config_dump?resource=static_route_configs' | tr -d ' \n' | grep -o '"prefix":"/reports/"},"route":{[^}]*' | grep -o '"timeout":"[0-9.]*s"' | head -n 1)"
check_eq "The /reports/ route has timeout 10s" '"timeout":"10s"' "$rt"
