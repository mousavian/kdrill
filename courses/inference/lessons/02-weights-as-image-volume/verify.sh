source "$KDRILL_HOME/courses/inference/lib.sh"
T='{.spec.template.spec'
settle llm 45 || true
vol="$(jp deploy/llm "$T.volumes[?(@.image)].name}")"
ref="$(jp deploy/llm "$T.volumes[?(@.image)].image.reference}")"
pol="$(jp deploy/llm "$T.volumes[?(@.image)].image.pullPolicy}")"
check_eq "The pod template has an image volume referencing the weights image" "$MODEL_IMAGE" "$ref"
why "volumes: - name: models / image: {reference: $MODEL_IMAGE, pullPolicy: IfNotPresent}   (kubectl explain pod.spec.volumes.image)"
check "... with pullPolicy IfNotPresent or Never (the reference only exists in the node, there is no registry)" bash -c '[[ "$1" == IfNotPresent || "$1" == Never ]]' _ "$pol"
why "Always makes the kubelet contact a registry for kdrill.local/..., which does not exist: the pod stays in ErrImagePull."
mnt="$(jp deploy/llm "$T.containers[0].volumeMounts[?(@.name==\"$vol\")].mountPath}")"
ro="$(jp deploy/llm "$T.containers[0].volumeMounts[?(@.name==\"$vol\")].readOnly}")"
check_eq "The container mounts that volume at /models" /models "$mnt"
check_eq "... read-only (an image volume cannot be written to)" true "$ro"
check_eq "No hostPath volume in the pod (weights must not depend on the node's disk)" "" "$(jp deploy/llm "$T.volumes[?(@.hostPath)].name}")"
check_eq "No init container (nothing is copied or downloaded at start)" "" "$(jp deploy/llm "$T.initContainers[*].name}")"
check_eq "The server image is still the stock llama.cpp image (weights are not baked into it)" "$LLAMA_IMAGE" "$(jp deploy/llm "$T.containers[0].image}")"
check "The pod is ready" test "$(ready_pods app=llm)" -ge 1
why "kubectl describe pod -l app=llm (events show image volume pull problems)"
check "A chat completion through the Service answers 200 with generated text" chat_ok http://llm/v1/chat/completions
why "kubectl logs deploy/llm"
