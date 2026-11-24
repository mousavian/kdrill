source "$KDRILL_HOME/courses/inference/lib.sh"
sel=app=llm
settle llm 45 || true
check "Deployment llm has one ready replica" test "$(jp deploy/llm '{.status.readyReplicas}')" = 1
why "kubectl get pods; kubectl logs deploy/llm (the server prints why it exits)"
check "The container still runs the pinned llama.cpp server image" test "$(jp deploy/llm '{.spec.template.spec.containers[0].image}')" = "$LLAMA_IMAGE"
why "The model server must stay llama.cpp's; fix the arguments, not the image."
check "Service llm has a ready endpoint" test "$(svc_endpoints llm)" -ge 1
why "kubectl get endpointslices -l kubernetes.io/service-name=llm. Compare the Service's targetPort with the port the server logs (listening on ...)."
check "GET /health answers ok" bash -c '[[ "$(kubectl exec client -- curl -s --max-time 10 http://llm/health)" == *ok* ]]'
out="$(kx curl -s --max-time 40 -w '\n%{http_code}' http://llm/v1/chat/completions -H 'content-type: application/json' \
  -d '{"model":"tiny","messages":[{"role":"user","content":"Say hello in five words."}],"max_tokens":8}')"
code="$(printf '%s' "$out" | tail -n 1)"
check_eq "POST /v1/chat/completions -> 200" 200 "$code"
check "The reply has a non-empty assistant message" bash -c '[[ "$1" == *"\"role\":\"assistant\""* && "$1" != *"\"content\":\"\""* ]]' _ "$out"
tokens="$(printf '%s' "$out" | sed -n 's/.*"completion_tokens":\([0-9]*\).*/\1/p')"
check "It generated between 1 and 8 tokens (max_tokens is honoured): usage.completion_tokens=${tokens:-?}" bash -c '[[ "${1:-0}" -ge 1 && "${1:-0}" -le 8 ]]' _ "$tokens"
check "The reply carries llama.cpp timings (a real model produced it)" bash -c '[[ "$1" == *"\"timings\""* && "$1" == *"predicted_per_second"* ]]' _ "$out"
