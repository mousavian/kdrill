Nothing is labelled yet. Look at the policy, and at what happens when you
touch a namespace:

    kubectl get deploy,sts -A -L cost-center | grep -v kube-system
    kubectl label ns research touched=1 --overwrite      # an UPDATE of the trigger
    kubectl get deploy -n research -L cost-center
    kubectl explain clusterpolicy.spec.mutateExistingOnPolicyUpdate
---
- A mutate-existing rule only fires when a trigger object (here a Namespace)
  is created or updated. `spec.mutateExistingOnPolicyUpdate: true` also runs
  it for all existing namespaces when the policy is created or changed.
- `mutate.targets` lists what to patch; add a second entry with
  `kind: StatefulSet`.
- Inside the patch, `request.object` is the *trigger* (the Namespace);
  `target` would be the object being patched.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory
    kubectl get deploy,sts -A -L cost-center | grep -v kube-system

The background controller applies the patches a few seconds later.
