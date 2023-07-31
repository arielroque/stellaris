# Stellaris

## :bookmark: Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/) 
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

## :triangular_flag_on_post: Starting

```bash
# Clone repository
git clone https://github.com/arielroque/stellaris.git
cd stellaris
```

## :building_construction: Running the Cluster

```bash
# Start cluster and registry
./start_cluster.sh
```

## :building_construction: Deploy Demo 

```bash
./demo.sh --deploy

# See another Commands:
# ./demo.sh --help
```

## :mag: Show Me the Answer


```bash
# Open port to access the client
kubectl port-forward client-api-0 -n client 8080:8080
```


```bash
curl https://localhost:3001/quotes
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```