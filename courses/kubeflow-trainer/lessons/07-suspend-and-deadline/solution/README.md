# Solution

From the lesson directory:

    kubectl patch trainjob explore --type=merge -p '{"spec":{"suspend":true}}'
    kubectl patch trainjob urgent  --type=merge -p '{"spec":{"suspend":false}}'
    kubectl patch trainjob runaway --type=merge -p '{"spec":{"activeDeadlineSeconds":20}}'
    kdrill verify            # urgent takes about 20 s

- `spec.suspend: true` on a TrainJob makes the controller suspend its JobSet, which suspends the Jobs: the
  pods are deleted. The TrainJob, JobSet and Jobs remain, and the TrainJob gets the condition
  `Suspended=True`. Setting it back to `false` creates new pods. Nothing was checkpointed, so `explore` would
  start from step 0 when resumed: suspension frees resources, it does not pause the process.
- `urgent` was created with `suspend: true`, so it never started; resuming it changed the condition to
  `Suspended=False` with reason `Resumed` and started its pod.
- `activeDeadlineSeconds` is a limit on how long a TrainJob may run (counted from its creation, or from the last
  resume). When it passes, the controller deletes the JobSet (and with it every pod) and sets the TrainJob
  `Failed` with reason `DeadlineExceeded`. Adding it to a TrainJob that has none is allowed once (so `runaway`
  needed no re-creation); changing it afterwards is refused (`field is immutable`). Because `runaway` was
  already older than 20 s, it was stopped at once; on a fresh TrainJob the timer would have run 20 s.
- A TrainJob that ended `Failed` or `Complete` stays in the cluster as a record until you delete it (or
  until something garbage-collects it); its pods are gone only because the deadline deleted the JobSet.
