# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

    terminationGracePeriodSeconds: 30
    lifecycle:
      preStop:
        sleep: {seconds: 8}

What happens when Kubernetes deletes a pod (a rollout, a scale-down, a node drain):

1. The pod is marked terminating. Two things start **in parallel**: the endpoint
   controller removes it from the Service's endpoints (and kube-proxy, or the
   gateway's own endpoint watch, must hear about it), and the kubelet runs the
   `preStop` hook.
2. After `preStop` finishes, the kubelet sends SIGTERM. A well-behaved server stops
   accepting connections and finishes what it is doing.
3. After `terminationGracePeriodSeconds` in total (preStop included) it sends SIGKILL.

With `terminationGracePeriodSeconds: 1` step 3 came a second after the delete, killing
requests that needed 4.5 s. Even with a long grace period there is a race: SIGTERM
arrives while other nodes still route new requests to the pod, and a server that has
stopped listening answers them with "connection refused". The `preStop` sleep keeps
the server fully serving during exactly that window, and gives short in-flight
requests time to finish.

The budget: `preStop` (8 s: more than the endpoint propagation and more than the
slowest request here, 4.5 s) + the server's own drain + a margin = 30 s.

Real model servers: vLLM and TGI drain on SIGTERM, but a generation can last minutes, so
set the grace period to your longest allowed request (and use client-side retries for
the rest). Long-lived streaming connections also need the gateway to stop routing to the
pod (readiness failing first) before the connection is cut.
