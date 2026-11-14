source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
apply_lesson manifests/apps.yaml
baseline_save shared="pool_spec shared" etl="res_of deploy/etl team-a" web="res_of deploy/web team-b" metrics="res_of deploy/metrics platform" \
  metricsspec="kubectl -n platform get deploy metrics -o jsonpath='{.spec.template.spec}'"
karp_wait_running team-a app=etl 4 60
