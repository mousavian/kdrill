# The shared ML image kdrill.local/ml-tiny (CPU-only PyTorch, a tiny
# character-level GPT, its corpus): built once on the host from
# base/images/ml-tiny and imported into the cluster on every start.
"$KDRILL_HOME/base/images/ml-tiny/build.sh" >/dev/null || die "could not build or import the ml-tiny image"
info "$(grep -m1 '^ML_TINY_VERSION=' "$KDRILL_HOME/base/images/ml-tiny/build.sh" | sed 's/ML_TINY_VERSION=/kdrill.local\/ml-tiny:/') is in the cluster"
