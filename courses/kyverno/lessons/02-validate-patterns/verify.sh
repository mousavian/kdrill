source "$KDRILL_HOME/courses/kyverno/lib.sh"
NS=ml-serving
TAG="use a pinned image tag, not latest or no tag"
REG="not from an approved registry"
kyv_settle

check "ClusterPolicy pod-standards exists and is Ready" policy_ready pod-standards
check_eq "All three rules exist and Enforce" "disallow-latest=Enforce require-resources=Enforce restrict-registries=Enforce" \
  "$(rule_actions pod-standards | tr ' ' '\n' | sort | paste -sd' ' -)"

echo "image tags"
check_rejects "Container image :latest is rejected (\"$TAG\")" latest.yaml "$TAG"
check_rejects "Container image without a tag is rejected (\"$TAG\")" untagged.yaml "$TAG"
why "No tag means :latest. A pattern can combine conditions: \"*:* & !*:latest\"."
check_rejects "initContainer image :latest is rejected (\"$TAG\")" init-latest.yaml "$TAG"
why "A pattern only checks the fields it names. =(initContainers): checks them only when present."

echo "registries"
check_rejects "docker.io image is rejected, message names it" dockerhub.yaml "docker.io/library/python:3.12"
check_rejects "Rejection message says \"$REG\"" dockerhub.yaml "$REG"
check_rejects "quay.io initContainer image is rejected, message names it" init-quay.yaml "quay.io/tools/init:2.0"
why "Put a variable in the message, e.g. {{ request.object.spec.[initContainers, containers][][].image }}."

echo "unchanged / not too strict"
check_rejects "Container without a memory limit is still rejected" no-limits.yaml "every container needs cpu and memory requests"
check_admits "A compliant Pod (ghcr.io/acme init, registry.acme.io main, pinned tags) is admitted" good.yaml
check_admits "A copy of the compliant ranker Deployment is admitted" deployment-good.yaml
check_eq "Deployment ranker: 2 replicas ready" 2 "$(jp deploy/ranker '{.status.readyReplicas}' -n $NS)"
