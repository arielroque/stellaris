# Stellaris

## :bookmark: Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/) 
- [Docker Compose](https://docs.docker.com/compose/install/) 
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

## :triangular_flag_on_post: Starting


```bash
# Clone repository
git clone https://github.com/arielroque/stellaris.git
cd stellaris

#Start minikube
minikube start --cpus=2 --memory='1.8g'  --nodes 3 -p node-demo   --extra-config=apiserver.service-account-signing-key-file=/var/lib/minikube/certs/sa.key     --extra-config=apiserver.service-account-key-file=/var/lib/minikube/certs/sa.pub     --extra-config=apiserver.service-account-issuer=api     --extra-config=apiserver.service-account-api-audiences=api,spire-server     --extra-config=apiserver.authorization-mode=Node,RBAC
```

```bash
kubectl port-forward client-api-0 -n spire 3000:8080

```


```bash
curl https://localhost:3001/quotes
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```