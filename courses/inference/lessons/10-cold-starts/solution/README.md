# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

Three changes:

    # ScaledObject
    minReplicaCount: 1                 # was 0: one warm replica, so the first request finds a server
    # Deployment, container sim
    imagePullPolicy: IfNotPresent      # was Always
    startupProbe: {periodSeconds: 2, failureThreshold: 30}   # was 10 / 12 (same 60 s budget)

What a cold start costs, in order: **node** (if no node has room: provisioning a GPU
node takes minutes: see the karpenter course), **image pull** (the server image, several GB for
CUDA ones; avoided when the node already has it: pre-pulled images, a cache, or
`IfNotPresent`), **weights** (from the node's cache, a PVC or an image volume: lesson
02; from object storage it can dominate), **load and warm-up** (read weights into
GPU memory, compile CUDA graphs: 20 s here, minutes for large models), and finally
the **probe interval** before Kubernetes notices. You can remove the first three
by design and the last by tuning; the load time stays, which is why a warm minimum
is the usual answer for latency-sensitive endpoints, and scale-to-zero is
for models used rarely enough that one slow first request is acceptable
(and then something must hold that request while the server starts: an
activator such as the KEDA HTTP add-on, Knative or KServe).
