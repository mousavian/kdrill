# Solution

From the lesson directory:

    kubectl apply -f solution/workers-svc.yaml
    kubectl delete job ddp
    kubectl apply -f solution/ddp.yaml
    kubectl logs -f -l batch.kubernetes.io/job-name=ddp --prefix

Both logs show `all 2 workers connected`, then the same training curve.

- `MASTER_ADDR=ddp-0.workers` is rank 0's DNS name: an Indexed Job's pod
  gets the hostname `<job>-<index>` (`ddp-0`, `ddp-1`), and a pod with
  `subdomain: X` gets a DNS record `<hostname>.X.<namespace>.svc` **if a
  headless Service named X selects it**. There was no Service, and the pods'
  subdomain was `worker`, not `workers`, so the name never resolved and both
  workers waited until `DIST_TIMEOUT`.
- `clusterIP: None` makes the Service headless: no load-balanced virtual IP,
  DNS answers with the pods themselves. `publishNotReadyAddresses: true`
  publishes the records as soon as the pods exist, which is when the
  rendezvous happens.
- Rank 0 runs the rendezvous store on port 29500 and both ranks then connect
  to each other directly (gloo, the CPU backend; NCCL on GPUs). Each worker
  trains on its own batches of 16 and DDP averages the gradients every step,
  so the two copies of the model stay identical; only rank 0 writes
  `metrics.json`, listing both workers.
