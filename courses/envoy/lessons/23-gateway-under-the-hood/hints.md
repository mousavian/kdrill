The route status says what's wrong:

    kubectl get httproute shop -o yaml | sed -n '/^status:/,$p'
    kubectl get svc cart

Then open the admin interface of the Gateway's Envoy. It listens on
127.0.0.1:19000 inside the pod, so port-forward to it:

    kubectl port-forward deploy/edge 19000 &
    curl -s localhost:19000/listeners
    curl -s 'localhost:19000/config_dump?resource=dynamic_route_configs' | less
    curl -s localhost:19000/clusters | grep cx_active
---
Record what you find:

    kubectl create configmap answers \
      --from-literal=listener=<name from /listeners> \
      --from-literal=port=<port from /listeners> \
      --from-literal=virtual_host=<virtual host whose domains contain shop.lab> \
      --from-literal=cart_cluster=<cluster of the route with prefix /cart> \
      --from-literal=cart_endpoints="<ip:port ip:port>"

(re-create with `--dry-run=client -o yaml | kubectl apply -f -` to update).
The endpoints only exist once the backendRef points at the right port.
---
    kubectl apply -f solution/shop.yaml      # from the lesson directory
    sh solution/answers.sh                   # reads the answers through a port-forward
