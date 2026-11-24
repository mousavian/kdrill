check_eq "Deployment web still asks for 3 replicas" 3 "$(jp deploy/web '{.spec.replicas}')"
why "Scaling down is not the fix — the app needs 3 replicas."

check_eq "All 3 replicas are Running and ready" 3 "$(jp deploy/web '{.status.readyReplicas}')"
why "Look at the Pending pod: kubectl describe pod <name>, then read the Events at the bottom."

req="$(jp deploy/web '{.spec.template.spec.containers[0].resources.requests.cpu}')"
check_ge "Each pod requests at least 1 CPU (1000m)" 1000 "$(cpu_millis "$req")"
why "Removing the request (or going below 1 CPU) would let it schedule, but the app really needs 1 CPU."

check_eq "There are still exactly 2 worker nodes" 2 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
why "Adding nodes costs money. Make the workload fit the nodes you have."

check_eq "node-a still has 4 allocatable CPUs" 4 "$(jp node/node-a '{.status.allocatable.cpu}')"
check_eq "node-b still has 4 allocatable CPUs" 4 "$(jp node/node-b '{.status.allocatable.cpu}')"
