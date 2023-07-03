#!/bin/bash

set -e

bold=$(tput bold)
bb=$(tput bold)
nn=$(tput sgr0)
bold=$(tput bold)
norm=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)

function deploy_minikube() {
    minikube start \
        --cpus=2 \
        --memory='1.8g' \
        --nodes 3 \
        --extra-config=apiserver.service-account-signing-key-file=/var/lib/minikube/certs/sa.key \
        --extra-config=apiserver.service-account-key-file=/var/lib/minikube/certs/sa.pub \
        --extra-config=apiserver.service-account-issuer=api \
        --extra-config=apiserver.service-account-api-audiences=api,spire-server \
        --extra-config=apiserver.authorization-mode=Node,RBAC
    
    # Enable registry addon
    minikube addons enable registry  
}

function deploy_register_container_aux(){
    docker run --name register-container-aux --rm -d -t --network=host alpine ash -c "apk add socat && socat TCP-LISTEN:5000,reuseaddr,fork TCP:$(minikube ip):5000"
}

function cleanup() {
	echo -n "${bold}Cleaning up... ${norm}"

    minikube delete --all
    minikube addons enable registry  
    docker rm register-container-aux -f  >/dev/null 2>&1
	
	echo "${green}ok${norm}."
}

# trap cleanup EXIT

deploy_minikube
deploy_register_container_aux

