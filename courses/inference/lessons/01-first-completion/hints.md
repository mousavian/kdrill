Two separate things are wrong. Start with the pod, not the Service:

    kubectl get pods
    kubectl logs deploy/llm
    kubectl exec deploy/llm -- ls /models      # while it runs; or read the hostPath in the Deployment

The server tells you which file it tried to load. When the pod is ready, look at
`kubectl get endpointslices -l kubernetes.io/service-name=llm` (no endpoints = the Service
does not select a ready pod) and at the port in the server's log line "listening on".
---
1. `-m` needs the real file name in /models: `smollm2-135m-instruct-q4_k_m.gguf`.
2. llama.cpp listens on 8080 (the image sets LLAMA_ARG_PORT=8080), and the container
   already declares it as port `http`. The Service's `targetPort` must name that port.

    kubectl edit deploy llm
    kubectl edit svc llm
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl exec client -- ask -v -p "Say hello." http://llm/v1/chat/completions
