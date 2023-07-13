#!/bin/bash
set -ex

type az gh > /dev/null

template_install() {
    template_file="install.sh"
    sed_script="s|{{token}}|${RUNNER_TOKEN}|g"
    sed_script="${sed_script};s|{{repo}}|${GITHUB_REPO}|g"
    sed_script="${sed_script};s|{{label}}|${UNIQ_LABEL}|g"
    sed "${sed_script}" "${template_file}.template" > "${template_file}"
}

: "${RESOURCE_GROUP_NAME:='testazcli'}"
: "${LOCATION:='northeurope'}"
: "${VM_IMAGE:='Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest'}"
: "${VM_SIZE:='Standard_B1s'}"
VM_NAME="${RESOURCE_GROUP_NAME}vm"
VM_USERNAME='vm'

if [[ -z $GITHUB_REPO ]];then
    >&2 echo "env var GITHUB_REPO not defined" 
    exit 1
fi

if [[ -z $GH_TOKEN ]];then
    >&2 echo "env var GH_TOKEN not defined" 
    exit 1
fi

UNIQ_LABEL=$(shuf -er -n8  {a..z} | paste -sd "")
RUNNER_TOKEN=$(gh api -XPOST --jq '.token' "repos/${GITHUB_REPO}/actions/runners/registration-token")

echo "${GH_TOKEN}" | sed "s/^\$/_/g" | gh auth login --with-token

if [[ $1 = '--destroy' ]]; then
    echo "Unregister runner"
    # Set up destroy script
    template_install
    VM_IP=$(az vm show --show-details --resource-group $RESOURCE_GROUP_NAME --name $VM_NAME --query publicIps --output tsv)
    ssh-keyscan "${VM_IP}" >> "${HOME}/.ssh/known_hosts"
    ssh "${VM_USERNAME}@${VM_IP}" 'bash -s -- --destroy' < install.sh
    ssh-keygen -R "${VM_IP}"
    # Delete the resource group
    echo "Deleting resource group"
    az group delete --name $RESOURCE_GROUP_NAME --no-wait --yes --output none
    exit 0
fi

# Create the resource group
echo "Creating resource group"
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION --output none

# Set up install script
template_install

# Create the debian vm
echo "Creating vm"
az vm create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VM_NAME \
    --image $VM_IMAGE \
    --admin-username $VM_USERNAME \
    --size $VM_SIZE \
    --ssh-key-values "${HOME}/.ssh/id_rsa.pub" \
    --custom-data install.sh \
    --public-ip-sku Standard \
    --output none
