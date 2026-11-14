#!/bin/sh
# Reads the answers from the Gateway's Envoy and stores them in the ConfigMap
# `answers`. Run from anywhere with kubectl pointing at the lab namespace.
pod=$(kubectl get pod -l gateway.envoyproxy.io/owning-gateway-name=edge -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward "pod/$pod" 19000:19000 >/dev/null 2>&1 & pf=$!
sleep 2
listener=$(curl -s localhost:19000/listeners | grep '^lab/edge/' | cut -d: -f1)
port=$(curl -s localhost:19000/listeners | grep '^lab/edge/' | sed 's/.*://')
vhost=$(curl -s 'localhost:19000/config_dump?resource=dynamic_route_configs' | grep -o '"name": "lab/edge/http/shop[^"]*"' | head -n 1 | cut -d'"' -f4)
cluster=$(curl -s 'localhost:19000/config_dump?resource=dynamic_route_configs' | grep -B3 -A30 '"prefix": "/cart"' | grep -o '"cluster": "[^"]*"' | head -n 1 | cut -d'"' -f4)
eps=$(curl -s localhost:19000/clusters | grep "^$cluster::" | grep '::cx_active::' | cut -d: -f3-4 | sed 's/::.*//' | sort | tr '\n' ' ')
kill $pf
kubectl create configmap answers --from-literal=listener="$listener" --from-literal=port="$port" \
  --from-literal=virtual_host="$vhost" --from-literal=cart_cluster="$cluster" \
  --from-literal=cart_endpoints="$eps" --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap answers -o yaml | sed -n '/^data:/,/^kind:/p'
