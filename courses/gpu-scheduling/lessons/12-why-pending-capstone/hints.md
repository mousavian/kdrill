Triage by symptom. Pods that exist but are Pending: read their
`FailedScheduling` events (`kubectl -n prod describe pod -l app=<name>`).
Workloads with no pods at all: look at the controller (`describe rs`,
`describe job`) and, for Kueue jobs, `kubectl -n research get workloads`.
---
The six causes are all different: an untolerated taint, a label value that
matches no node, a MIG profile no node offers, a DeviceClass that doesn't
exist, a LocalQueue name that doesn't exist, and a quota that requires CPU and
memory requests. Match each workload to one.
---
From the lesson directory:

    kubectl -n prod delete resourceclaimtemplate l40s-gpu       # templates are immutable
    kubectl apply -f solution/prod.yaml -f solution/research.yaml
    kubectl -n prod rollout restart deploy vision               # new pod -> new claim from the fixed template

Each fix is marked `# FIX n` in the solution files.
