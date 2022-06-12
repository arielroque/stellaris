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
        -node  \
        -spiffeID spiffe://example.org/ns/spire/sa/spire-agent \
        -selector k8s_sat:cluster:minikube \
        -selector k8s_sat:agent_ns:spire \
        -selector k8s_sat:agent_sa:spire-agent
}

function apply_server_config() {
	echo -n "${bold}Applying SPIRE server k8s configuration... ${norm}"
	kubectl apply -f ${DIR}/spire/spire-namespace.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/server-account.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/server-cluster-role.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/server-configmap.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/spire-bundle-configmap.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/server-statefulset.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/server-service.yaml > /dev/null

	sleep 5

	SPIRE_SERVER=$(kubectl get pods -n spire \
		    -o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)

	until kubectl get pods $SPIRE_SERVER -n spire \
		-o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep True;
	do 
		sleep 5; 
	done;

	echo "${green}ok.${norm}"
}

function apply_agent_config() {
	echo -n "${bold}Applying SPIRE agent k8s configuration... ${norm}"
	kubectl apply -f ${DIR}/spire/agent-account.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/agent-cluster-role.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/agent-configmap.yaml > /dev/null
	kubectl apply -f ${DIR}/spire/agent-daemonset.yaml > /dev/null

	sleep 5

	SPIRE_AGENT=$(kubectl get pods -n spire \
		    -o=jsonpath='{.items[0].metadata.name}' -l app=spire-agent)

	until kubectl get pods $SPIRE_AGENT -n spire \
		-o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep True;
	do 
		sleep 5; 
	done;

	echo "${green}ok.${norm}"
}


function check_for_node_attestation() {

    SPIRE_SERVER_POD_NAME=$(kubectl get pods -n spire \
          -o=jsonpath='{.items[0].metadata.name}' -l app=spire-server)


	for i in $(seq 60); do
		sleep ${CHECKINTERVAL}
		echo -n "${bold}Checking for node attestation... ${norm}"
		kubectl -n spire logs ${SPIRE_SERVER_POD_NAME} > ${SERVERLOGS} || true
		if  grep -sxq -e ".*Agent attestation request completed.*k8s_sat.*" ${SERVERLOGS}; then
			echo "${green}ok${norm}."
			return
		fi
		echo "${yellow}nope${norm}."
	done

	echo "${red}FAILED: node attestation did not succeed in time.${norm}" >&2
	echo "${yellow}Log at ${SERVERLOGS}${norm}" >&2
	exit -1
}

function tear_down_config() {
	kubectl delete namespace spire > /dev/null || true
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
	kubectl apply -f ${DIR}/client/client-statefulset.yml
}

function deploy_stellaris {
	echo -n "${bold}Deploying Stellaris... ${norm}"
	kubectl apply -f ${DIR}/stellaris/stellaris-statefulset.yml
}

function build_images {

	eval $(minikube docker-env)

	(cd "${DIR}"/client/src && CGO_ENABLED=0 GOOS=linux go build -v -o "${DIR}"/client/src)
    (cd "${DIR}"/stellaris/src && CGO_ENABLED=0 GOOS=linux go build -v -o "${DIR}"/stellaris/src)

    cd "${DIR}"/client && docker build -t stellaris-client -f client.Dockerfile .
	cd "${DIR}"/stellaris && docker build -t stellaris-api -f stellaris.Dockerfile . 

	#eval $(minikube docker-env)
}


function cleanup() {
	echo -n "${bold}Cleaning up... ${norm}"
	if [ ! -z "${SUCCESS}" ]; then
		rm -rf ${TMPDIR}
	fi
	tear_down_config
	echo "${green}ok${norm}."
}


#trap cleanup EXIT
cleanup

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
