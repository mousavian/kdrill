# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

Two fixes:

- `-m /models/smollm2.gguf` -> `-m /models/smollm2-135m-instruct-q4_k_m.gguf`. The
  weights are one file in the node's hostPath `/var/lib/kdrill/models`; llama.cpp
  exits with an error when the path does not exist, so the pod crash-looped.
- Service `targetPort: 8000` -> `http` (the container's named port 8080). The
  llama.cpp server listens on 8080; nothing listened on 8000, so even a healthy pod
  would have answered "connection refused" through the Service.

Naming the target port (`targetPort: http`) keeps the Service correct if the
container port number ever changes.
