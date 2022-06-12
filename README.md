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
minikube start     --extra-config=apiserver.service-account-signing-key-file=/var/lib/minikube/certs/sa.key     --extra-config=apiserver.service-account-key-file=/var/lib/minikube/certs/sa.pub     --extra-config=apiserver.service-account-issuer=api     --extra-config=apiserver.service-account-api-audiences=api,spire-server     --extra-config=apiserver.authorization-mode=Node,RBAC
```