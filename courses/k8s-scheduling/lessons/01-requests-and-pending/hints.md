Find the pod that is Pending and run `kubectl describe pod` on it. The last
lines (Events) say exactly which resource is short.
---
Each node has 4 allocatable CPUs. Each pod asks for 3. How many 3-CPU pods fit
on one 4-CPU node? How many would fit if the request were smaller?
---
You need 3 pods on 2 nodes, so one node must hold 2 pods: 2 × request ≤ 4 CPUs.
Any CPU request between 1 and 2 works. Change it with
`kubectl set resources deploy web --requests=cpu=...` or `kubectl edit deploy web`.
