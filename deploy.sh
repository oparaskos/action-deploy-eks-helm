#!/usr/bin/env bash
set -euxo pipefail

# "catch exit status 1" grep wrapper
_grep() { grep "$@" || test $? = 1; }

aws --version

echo "Logging into kubernetes cluster $CLUSTER_NAME"
if [ -n "$CLUSTER_ROLE_ARN" ]; then
    aws eks \
        --region "${AWS_REGION}" \
        update-kubeconfig --name "${CLUSTER_NAME}" \
        --role-arn="${CLUSTER_ROLE_ARN}"
else
    aws eks \
        --region "${AWS_REGION}" \
        update-kubeconfig --name "${CLUSTER_NAME} "
fi

kubectl version

# Check if namespace exists and create it if it doesn't.
KUBE_NAMESPACE_EXISTS=$(kubectl get namespaces | _grep ^${DEPLOY_NAMESPACE})
if [ -z "${KUBE_NAMESPACE_EXISTS}" ]; then
    echo "The namespace ${DEPLOY_NAMESPACE} does not exists. Creating..."
    kubectl create namespace "${DEPLOY_NAMESPACE}"
else
    echo "The namespace ${DEPLOY_NAMESPACE} exists. Skipping creation..."
fi

helm version

# Install any required helm plugins
if [ -n "${HELM_PLUGINS}" ]; then
    for PLUGIN_URL in ${HELM_PLUGINS//,/ }
    do
        helm plugin install "${PLUGIN_URL}"
    done
    helm plugin list
fi

# Checking to see if a repo URL is in the path, if so add it or update.
if [ -n "${HELM_REPOSITORY}" ]; then
    HELM_CHART_NAME="${DEPLOY_CHART_PATH%/*}"

    HELM_REPOS=$(helm repo list || true)
    CHART_REPO_EXISTS=$(echo $HELM_REPOS | _grep ^${HELM_CHART_NAME})
    if [ -z "${CHART_REPO_EXISTS}" ]; then
        echo "Adding repo ${HELM_CHART_NAME} (${HELM_REPOSITORY})"
        helm repo add "${HELM_CHART_NAME}" "${HELM_REPOSITORY}"
    else
        echo "Updating repo ${HELM_CHART_NAME}"
        helm repo update "${HELM_CHART_NAME}"
    fi
fi

# Upgrade or install the chart.  This does it all.
HELM_COMMAND="helm upgrade --install --timeout ${TIMEOUT}"

# Set paramaters
for config_file in ${DEPLOY_CONFIG_FILES//,/ }
do
    HELM_COMMAND="${HELM_COMMAND} -f ${config_file}"
done
if [ -n "$DEPLOY_NAMESPACE" ]; then
    HELM_COMMAND="${HELM_COMMAND} -n ${DEPLOY_NAMESPACE}"
fi
if [ -n "$DEPLOY_VALUES" ]; then
    HELM_COMMAND="${HELM_COMMAND} --set ${DEPLOY_VALUES}"
fi

# Execute Commands
HELM_COMMAND="${HELM_COMMAND} ${DEPLOY_NAME} ${DEPLOY_CHART_PATH}"
echo "Executing: ${HELM_COMMAND}"
${HELM_COMMAND}
