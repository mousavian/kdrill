source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
# The first 200,000 characters of the corpus: all a ConfigMap could be given.
tmp="${TMPDIR:-/tmp}/kdrill-slice.$$"
inspect_up
ix head -c 200000 /opt/ml-tiny/data/tinyshakespeare.txt > "$tmp" || die "could not read the corpus from the image"
inspect_down
kubectl create configmap corpus --from-file=input.txt="$tmp" >/dev/null
rm -f "$tmp"
apply_lesson manifests/job.yaml
info "job/train trains on the 200 KB ConfigMap 'corpus' (the full corpus is 1.1 MB)"
