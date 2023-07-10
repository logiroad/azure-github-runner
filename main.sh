#!/bin/bash
set -e

type az gh > /dev/null

template_install() {
    template_file="install.sh"
    sed_script="s|{{token}}|${TOKEN}|g"
    sed_script="${sed_script};s|{{repo}}|${REPO}|g"
    sed_script="${sed_script};s|{{label}}|${UNIQ_LABEL}|g"
    sed "${sed_script}" "${template_file}.template" > "${template_file}"
}

RESOURCE_GROUP_NAME=testazcli
LOCATION=northeurope
VM_NAME="${RESOURCE_GROUP_NAME}vm"
VM_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
REPO="user/repo"
VM_USERNAME=vm

UNIQ_LABEL=$(cat /dev/urandom | tr -cd '[:alpha:]' | head -c 6)
TOKEN=$(gh api -XPOST --jq '.token' "repos/${REPO}/actions/runners/registration-token")

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
    --size "Standard_B1s" \
    --ssh-key-values "${HOME}/.ssh/id_rsa.pub" \
    --custom-data install.sh \
    --public-ip-sku Standard \
    --output none
