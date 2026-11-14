# The learner creates this cluster-scoped DeviceClass.
kubectl delete deviceclass gpu.nvidia.com --ignore-not-found >/dev/null
