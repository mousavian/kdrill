source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
N=200
marker="kdrill-$RANDOM$RANDOM"
settle 2

echo "config"
check_eq "VirtualService catalog still exists" catalog "$(jp virtualservice/catalog '{.metadata.name}' -n $NS)"
check_eq "DestinationRule catalog still defines v1 v2 v3" "v1 v2 v3" "$(jp destinationrule/catalog '{.spec.subsets[*].name}' -n $NS)"

echo "traffic: $N requests web -> catalog"
got="$(backends $NS web "http://catalog:8000/hostname?probe=$marker" $N)"
v1="$(count_of catalog-v1 "$got")"; v2="$(count_of catalog-v2 "$got")"; v3="$(count_of catalog-v3 "$got")"; err="$(count_of error "$got")"
echo "    (answers: ${got:-none})"
check "About 80% answered by v1 (140-180 of $N; got $v1)" between 140 180 "$v1"
check "About 20% answered by v2 (20-60 of $N; got $v2)" between 20 60 "$v2"
why "Weights on the route's destinations must add up to 100: v1 80, v2 20."
check_eq "No answer came from v3" 0 "$v3"
why "v3 must not be a weighted destination. A mirror's responses are thrown away."
check_eq "No failed requests" 0 "$err"

echo "mirroring"
seen=0
for p in $(live_pods $NS app=catalog,version=v3); do
  c="$(kubectl -n $NS logs "$p" -c catalog --since=2m 2>/dev/null | grep -c "$marker")"
  seen=$((seen + c))
done
check "v3 received a copy of (almost) every request (at least 180 of $N; got $seen)" between 180 $((N * 2)) "$seen"
why "mirror: {host: catalog, subset: v3} with mirrorPercentage: {value: 100}. Check: kubectl -n shop logs deploy/catalog-v3 -c catalog"
