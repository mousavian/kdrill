The server exits because /models is an empty directory. Think about what should
provide the file: it must be mounted into the pod, read-only, and come from an
image the node already has. Look at:

    kubectl explain pod.spec.volumes.image
    kubectl get pod -l app=llm -o jsonpath='{.items[0].spec.volumes}'
---
Replace the `emptyDir` volume with an `image` volume:

      volumes:
      - name: models
        image:
          reference: kdrill.local/smollm2-135m:q4km
          pullPolicy: IfNotPresent

and mount it read-only at /models. This image (`FROM scratch` + one file) was built
by the course on `kdrill course start`; `Always` would try a registry that does not exist.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl exec client -- ask -v http://llm/v1/chat/completions
