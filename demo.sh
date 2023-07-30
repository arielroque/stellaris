#!/bin/bash

set -e

bb=$(tput bold)
nn=$(tput sgr0)
bold=$(tput bold)
norm=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)

DIR=$(pwd)
TMPDIR=$(mktemp -d)
CHECKINTERVAL=1
SERVERLOGS=${TMPDIR}/spire-server-logs.log

HELP="Usage: \n
\texp-setup --deploy\n 
\texp-setup --cleanup\n 
"

function create_workload_entry() {

	SPIRE_SERVER_POD_NAME=$(kubectl get pods -n spire \
		-o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	echo "${bb}Creating registration entry for the node...${nn}"

	kubectl exec -n spire $SPIRE_SERVER_POD_NAME -- \
		/opt/spire/bin/spire-server entry create \
		-spiffeID spiffe://example.org/client-wl \
		-parentID spiffe://example.org/ns/spire/sa/spire-agent \
		-selector k8s:container-name:client-api

	kubectl exec -n spire $SPIRE_SERVER_POD_NAME -- \
		/opt/spire/bin/spire-server entry create \
		-spiffeID spiffe://example.org/stellaris-wl \
		-parentID spiffe://example.org/ns/spire/sa/spire-agent \
		-selector k8s:container-name:stellaris-api
}

function create_agent_entry() {

	SPIRE_SERVER_POD_NAME=$(kubectl get pods -n spire \
		-o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	echo "${bb}Creating registration entry for the node...${nn}"
	kubectl exec -n spire $SPIRE_SERVER_POD_NAME -- \
		/opt/spire/bin/spire-server entry create \
		-node \
		-spiffeID spiffe://example.org/ns/spire/sa/spire-agent \
		-selector k8s_sat:cluster:minikube \
		-selector k8s_sat:agent_ns:spire \
		-selector k8s_sat:agent_sa:spire-agent
}

function apply_server_config() {
	echo -n "${bold}Applying SPIRE server k8s configuration... ${norm}"
	kubectl apply -f ${DIR}/spire/spire-namespace.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/server-account.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/server-cluster-role.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/server-configmap.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/spire-bundle-configmap.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/server-service.yaml >/dev/null

	envsubst <${DIR}/spire/server-statefulset.yaml | kubectl apply -f -

	sleep 5

	SPIRE_SERVER=$(kubectl get pods -n spire \
		-o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	until kubectl get pods $SPIRE_SERVER -n spire \
		-o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep True; do
		sleep 5
	done

	echo "${green}ok.${norm}"
}

function apply_agent_config() {
	echo -n "${bold}Applying SPIRE agent k8s configuration... ${norm}"
	kubectl apply -f ${DIR}/spire/agent-account.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/agent-cluster-role.yaml >/dev/null
	kubectl apply -f ${DIR}/spire/agent-configmap.yaml >/dev/null

	SPIRE_AGENT_NODE=$SPIRE_AGENT1_NODE
	envsubst <${DIR}/spire/agent-daemonset.yaml | kubectl apply -f -

	SPIRE_AGENT_NODE=$SPIRE_AGENT2_NODE
	envsubst <${DIR}/spire/agent-daemonset.yaml | kubectl apply -f -

	sleep 5

	SPIRE_AGENT=$(kubectl get pods -n spire \
		-o=jsonpath='{.items[0].metadata.name}' -l app=spire-agent)

	until kubectl get pods $SPIRE_AGENT -n spire \
		-o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep True; do
		sleep 5
	done

	echo "${green}ok.${norm}"
}

function check_for_node_attestation() {

	SPIRE_SERVER_POD_NAME=$(kubectl get pods -n spire \
		-o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	for i in $(seq 60); do
		sleep ${CHECKINTERVAL}
		echo -n "${bold}Checking for node attestation... ${norm}"
		kubectl -n spire logs ${SPIRE_SERVER_POD_NAME} >${SERVERLOGS} || true
		if grep -sxq -e ".*Agent attestation request completed.*k8s_sat.*" ${SERVERLOGS}; then
			echo "${green}ok${norm}."
			return
		fi
		echo "${yellow}nope${norm}."
	done

	echo "${red}FAILED: node attestation did not succeed in time.${norm}" >&2
	echo "${yellow}Log at ${SERVERLOGS}${norm}" >&2
	exit -1
}

function delete_entries {

	SPIRE_SERVER=$(kubectl get pods -n spire -o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	entries=$(kubectl exec -n spire $SPIRE_SERVER -- /opt/spire/bin/spire-server entry show | grep "Entry" | cut -d ':' -f 2)

	for entry in $entries; do
		kubectl exec -n spire $SPIRE_SERVER -- /opt/spire/bin/spire-server entry delete --entryID $entry
	done

	echo "Deleted entries from K8S!"
}

function deploy_client {
	echo -n "${bold}Deploying Client... ${norm}"
	kubectl create namespace client
	envsubst <${DIR}/client/client-statefulset.yml | kubectl apply -f -
}

function deploy_stellaris {
	echo -n "${bold}Deploying Stellaris... ${norm}"
	kubectl create namespace server
	envsubst <${DIR}/stellaris/stellaris-statefulset.yml | kubectl apply -f -
}

function build_images {

	(cd "${DIR}"/client/src && CGO_ENABLED=0 GOOS=linux go build -v -o "${DIR}"/client/src)
	(cd "${DIR}"/stellaris/src && CGO_ENABLED=0 GOOS=linux go build -v -o "${DIR}"/stellaris/src)

	cd "${DIR}"/client && docker build -t stellaris-client -f client.Dockerfile .
	cd "${DIR}"/stellaris && docker build -t stellaris-api -f stellaris.Dockerfile .

	docker tag stellaris-client localhost:5000/stellaris-client
	docker tag stellaris-api localhost:5000/stellaris-api

	docker push localhost:5000/stellaris-client
	docker push localhost:5000/stellaris-api
}

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

function deploy_demo() {
	cleanup_demo
	build_images
	apply_server_config
	delete_entries
	create_agent_entry
	create_workload_entry
	apply_agent_config
	check_for_node_attestation
	deploy_client
	deploy_stellaris

	echo "${bold}Success.${norm}"
}

function cleanup_demo() {

	namespaces=$(kubectl get ns)

	if [[ $namespaces != *"spire"* ]]; then
		return
	fi

	echo -n "${bold}Cleaning demo... ${norm}"
	
	if [ ! -z "${SUCCESS}" ]; then
		rm -rf ${TMPDIR}
	fi

	kubectl delete namespace spire >/dev/null || true
	kubectl delete namespace client >/dev/null || true
	kubectl delete namespace server >/dev/null || true

	echo "${green}ok${norm}."
}

function delete_minikube_cluster() {
	echo -n "${bold}Deleting minikube cluster ... ${norm}"

    minikube delete --all
    minikube addons enable registry  
    docker rm register-container-aux -f  >/dev/null 2>&1
	
	echo "${green}ok${norm}."
}

#trap cleanup EXIT

COMMAND=$1

case $COMMAND in
--deploy) deploy_demo ;;
--create-minikube-cluster) deploy_minikube ;; 
--cleanup-demo) cleanup_demo ;;
--delete-minikube-cluster) delete_minikube_cluster ;; 

*) echo -e "Invalid command!\n" && echo -e $HELP ;;
esac
