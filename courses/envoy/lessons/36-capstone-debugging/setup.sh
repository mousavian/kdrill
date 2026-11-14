source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend api --replicas 2
backend reports --no-service
backend checkout
kubectl -n payments apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata: {name: pay, labels: {app: pay}}
spec:
  replicas: 1
  selector: {matchLabels: {app: pay}}
  template:
    metadata: {labels: {app: pay}}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: whoami
        image: $WHOAMI_IMAGE
        env: [{name: WHOAMI_NAME, value: pay}]
        ports: [{name: http, containerPort: 80}]
        resources: {requests: {cpu: 5m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: pay}
spec:
  selector: {app: pay}
  ports: [{name: http, port: 80, targetPort: http}]
YAML
apply_lesson manifests/sites.yaml
lab_wait web api reports checkout
kubectl -n payments rollout status deploy/pay --timeout=120s >/dev/null
gw_wait edge
