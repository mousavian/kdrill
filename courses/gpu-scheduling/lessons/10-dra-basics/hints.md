The pods are Pending. Read their events, then look at what exists:

    kubectl describe pod -l app=vllm | tail
    kubectl get resourceslices
    kubectl get deviceclass
    kubectl get resourceclaimtemplates,resourceclaims

The ResourceSlices list 8 GPUs, but the pods reference a template that
doesn't exist, and no DeviceClass exists yet.
---
Two objects are missing. A **DeviceClass** (cluster-scoped) named
`gpu.nvidia.com` that matches the driver's devices with a CEL selector on
`device.driver`, and a **ResourceClaimTemplate** named `one-gpu` in this
namespace whose single request asks for one device of that class
(`exactly: {deviceClassName: gpu.nvidia.com}`).
`kubectl explain resourceclaimtemplate.spec.spec.devices.requests.exactly`
---
    kubectl apply -f solution/dra.yaml      # from the lesson directory

The Deployment's pods are already waiting: the resourceclaim controller
creates one claim per pod from the template, and the scheduler allocates a
device from a ResourceSlice on the node it picks. Then inspect a claim with
`kubectl get resourceclaim -o yaml`.
