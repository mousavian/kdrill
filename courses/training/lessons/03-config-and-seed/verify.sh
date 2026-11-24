source "$KDRILL_HOME/courses/training/lib.sh"
check "ConfigMap hparams exists" kubectl get configmap hparams
why "kubectl create configmap hparams --from-literal=STEPS=300 ..."
for k in STEPS LR BATCH_SIZE SEED; do
  check "hparams has key $k" test -n "$(jp configmap/hparams "{.data.$k}")"
done
check_ge "hparams STEPS is at least 300" 300 "$(jp configmap/hparams '{.data.STEPS}')"
check "hparams SEED is a number" bash -c '[[ "$1" =~ ^[0-9]+$ ]]' _ "$(jp configmap/hparams '{.data.SEED}')"
seed="$(jp configmap/hparams '{.data.SEED}')"
pending=""
for j in run-a run-b; do
  if ! kubectl get job "$j" >/dev/null 2>&1; then check "Job $j exists" false; continue; fi
  check "Job $j loads ConfigMap hparams with envFrom" bash -c '[[ " $1 " == *" hparams "* ]]' _ "$(jp job/$j '{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}')"
  why "envFrom: [{configMapRef: {name: hparams}}] in the container (re-create the Job)"
  a="$(jp job/$j '{.spec.template.spec.containers[0].args[*]} {.spec.template.spec.containers[0].command[*]}')"
  e="$(jp job/$j '{range .spec.template.spec.containers[0].env[*]}{.name} {end}')"
  check "Job $j sets no hyperparameter on the command line or as a literal env var" \
    bash -c '[[ ! "$1" =~ --(steps|lr|batch-size|seed) && ! " $2 " =~ \ (STEPS|LR|BATCH_SIZE|SEED)\  ]]' _ "$a" "$e"
  why "Flags and env entries win over envFrom; remove --steps/--lr/--batch-size/--seed and literal STEPS/LR/BATCH_SIZE/SEED."
  st="$(job_state "$j")"
  if [[ "$st" == running || "$st" == pending ]]; then pending+="$j($(progress_msg "$j")) "; continue; fi
  check_eq "Job $j completed" complete "$st"
done
if [[ -n "$pending" ]]; then
  check "Both runs have finished (still running: ${pending% }; about 30 s each)" false
  why "Wait and run kdrill verify again."
  exit 1
fi
la="$(job_logs run-a)"; lb="$(job_logs run-b)"
for j in a b; do
  l="$la"; [[ $j == b ]] && l="$lb"
  s="$(printf '%s\n' "$l" | sed -n 's/.* seed=\([0-9]*\)\([^ ]*\).*/\1\2/p' | head -n 1)"
  check_eq "run-$j used the seed from hparams" "$seed" "$s"
done
fa="$(final_loss "$la")"; fb="$(final_loss "$lb")"
check "run-a reached a loss below 2.9 (got ${fa:-none})" float_lt "$fa" 2.9
check "run-b reached a loss below 2.9 (got ${fb:-none})" float_lt "$fb" 2.9
check_eq "run-a and run-b reproduce the same final loss" "${fa:-?}" "${fb:-?}"
why "Same seed, same hyperparameters and the same OMP_NUM_THREADS give identical runs on CPU."
