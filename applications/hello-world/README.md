# Hello World
This application provides a simple hello world for debugging that the networking into the cluster is working correctly.

## Deployment: manual

```bash
kubectl apply -k .

kubectl apply -k applications/hello-world/
```

## Test

To test if the service is up use url:

```bash
nginx-hello-world.hello-world.svc.cluster.local
```


```bash
nslookup nginx-hello-world.hello-world.svc.cluster.local 192.168.178.10 
```

```bash
nslookup nginx-hello-world.hello-world.example.org 192.168.178.10 
```