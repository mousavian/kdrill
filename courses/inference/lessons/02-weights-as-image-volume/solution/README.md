# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

The change is one volume:

    volumes:
    - name: models
      image:
        reference: kdrill.local/smollm2-135m:q4km
        pullPolicy: IfNotPresent

mounted read-only at `/models`. The kubelet resolves the image like any other
(already present on the node, so nothing is pulled), mounts its filesystem into
the pod, and `/models/smollm2-135m-instruct-q4_k_m.gguf` is there. The server image
stays generic and can be shared by every model; the weights are a separate,
versioned, content-addressed artifact that the container runtime caches and
deduplicates per node.

Compared with the alternatives: baking weights into the server image makes every
model a new multi-gigabyte server image; an init container that copies or
downloads them pays that cost again on every pod start and needs a writable
volume; a hostPath only works on nodes someone prepared.
