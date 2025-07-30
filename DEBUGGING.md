# DEBUGGING

This page include some handy commands or debugging tips I have gathered


## Inspect PVC

To be able to inspect a PVC runt he following:
```bash
export CLAIM_NAME="coredns-blocklist"
export CLAIM_NAMESPACE="coredns-lan"
# Create a pod attached to the pvc claim
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-inspector
  namespace: $CLAIM_NAMESPACE
spec:
  containers:
  - image: busybox
    name: pvc-inspector
    command: ["sleep", "3600"]
    volumeMounts:
    - mountPath: /pvc
      name: pvc-volume
  volumes:
  - name: pvc-volume
    persistentVolumeClaim:
      claimName: $CLAIM_NAME
EOF

# Inspect it
kubectl exec -it pvc-inspector -n $CLAIM_NAMESPACE -- sh
cd /pvc
ls

# Delete the pod
kubectl delete pod pvc-inspector -n $CLAIM_NAMESPACE
```
