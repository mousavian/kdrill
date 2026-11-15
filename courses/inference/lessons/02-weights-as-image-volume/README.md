# Getting weights to the pod: an image volume

Model server: **real** (llama.cpp, SmolLM2-135M).

## Concept

A model server pod needs two things: the *server* (code, a few hundred MB) and
the *weights* (data, from 100 MB to hundreds of GB). Bundling them into one
image makes every model a new huge image; downloading them in an init container
makes every pod start pay the full transfer, needs scratch space as big as the
model and a credentials story; a `hostPath` or a ReadWriteMany PVC works only
where someone prepared the node or the storage.

Since Kubernetes 1.31 there is a fourth way: the **image volume**
(`volumes[].image`, beta and on by default from 1.35). The weights are packaged
as an OCI image or artifact (for example a `FROM scratch` image holding one
file), and the kubelet mounts that image's filesystem into the pod, read-only.
You get everything a container image gets: content-addressed layers, a registry,
signing, and a **per-node cache** shared by all pods, so a second replica on the
same node starts without moving a byte. What the container runtime does not
fix is the first pull: a 140 GB image is still 140 GB over the network, so big
fleets pre-pull or pre-warm nodes (lesson 10).

`pullPolicy` follows the usual rules: `IfNotPresent` reuses the node's copy,
`Always` contacts the registry on every pod start (a cheap manifest check for a
digest, a failure if the registry is unreachable), `Never` only uses what is
there. In this lab the weights image `kdrill.local/smollm2-135m:q4km` exists
only inside the node, so `Always` cannot work.

## The situation

The Deployment `llm` mounts an empty `emptyDir` at `/models`, so llama.cpp exits
with "failed to load model". The image `kdrill.local/smollm2-135m:q4km` is
already in the node (the course imported it); it contains the file
`/smollm2-135m-instruct-q4_k_m.gguf`.

## Your task

Use an image volume in the pod template, nothing else:

- a volume of type `image` referencing `kdrill.local/smollm2-135m:q4km`, pull policy
  `IfNotPresent` (or `Never`);
- mounted read-only at `/models`;
- no `hostPath`, no init container, the server image unchanged;
- the pod becomes ready and `http://llm/v1/chat/completions` answers.

## Useful commands

    kubectl explain pod.spec.volumes.image
    kubectl get pod -l app=llm -o jsonpath='{.items[0].spec.volumes}'
    kubectl describe pod -l app=llm
    kubectl logs deploy/llm

When you think you're done: `kdrill verify`

## On a real cluster

Weights usually live in a registry (as an OCI artifact: `oras`, `modctl`, or the
CNCF ModelPack format), in object storage with a downloader init container or a
cache such as Run:ai Model Streamer / `s3fs`, or on a shared volume. Pods that
mount an image volume need a container runtime that supports it (containerd 2.1+
or CRI-O 1.31+). KServe's "modelcar" feature is this same idea.

## Read more

- https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/
- https://kubernetes.io/docs/concepts/storage/volumes/#image
- https://kserve.github.io/website/latest/modelserving/storage/oci/
