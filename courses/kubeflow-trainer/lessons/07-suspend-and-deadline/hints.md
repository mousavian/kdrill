Look at the three TrainJobs, their states and their pods, and at where `suspend` lives:

    kubectl get trainjobs,jobsets,pods
    kubectl explain trainjob.spec.suspend
    kubectl explain trainjob.spec.activeDeadlineSeconds
---
Suspending and resuming are edits of `spec.suspend`, no need to delete anything:

    kubectl patch trainjob explore --type=merge -p '{"spec":{"suspend":true}}'
    kubectl patch trainjob urgent  --type=merge -p '{"spec":{"suspend":false}}'

`activeDeadlineSeconds` is a field of the TrainJob spec. The API lets you add it to a TrainJob that has none,
once; after that it cannot be changed. The timer counts from the creation of the TrainJob (or its last resume).
---
See solution/:

    kubectl patch trainjob explore --type=merge -p '{"spec":{"suspend":true}}'
    kubectl patch trainjob urgent  --type=merge -p '{"spec":{"suspend":false}}'
    kubectl patch trainjob runaway --type=merge -p '{"spec":{"activeDeadlineSeconds":20}}'
