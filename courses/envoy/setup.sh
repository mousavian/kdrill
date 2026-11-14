# Once per `course start`: pull the lab images into the node so the first
# lesson does not wait on downloads (Envoy Gateway's images came with its install).
source "$KDRILL_HOME/courses/envoy/lib.sh"
info "pre-pulling lab images (envoy, whoami, curl; about 60 MB, once)..."
prepull_images $LAB_IMAGES
