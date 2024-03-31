#!/bin/bash -x

# Configuration
location="westus"
rg="wandy"
nsg_name="myNSG"
srcaddressprefix="'*'"
master_prefix="k8strainingmaster"
worker_prefix="k8strainingworker"
vm_image="Ubuntu2204"
vm_size="Standard_B2s"
admin_username="ubuntu"
ssh_key_path="$HOME/.ssh/id_rsa.pub"
os_disk_size_gb="100"
public_ip_sku="Standard"
vnet_name="myVNet"
subnet_name="mySubnet"
address_prefix="10.0.0.0/16"
subnet_prefix="10.0.0.0/24"
domain="$location.cloudapp.azure.com"
number_of_masters=1
number_of_workers=2

master_vm_names=()
worker_vm_names=()
cluster_join_script_name="./workloadtojoin.sh"
create_vnet() {
  az network vnet create \
    --resource-group $rg \
    --name $vnet_name \
    --address-prefix $address_prefix \
    --subnet-name $subnet_name \
    --subnet-prefix $subnet_prefix \
    --location $location
}

create_nsg() {
  echo "Creating NSG: $nsg_name in Resource Group: $rg"
  az network nsg create \
    --resource-group $rg \
    --name $nsg_name \
    --location $location
}

create_nsg_rule() {
  az network nsg rule create \
    --resource-group $rg \
    --nsg-name $nsg_name \
    --name AllowSpecificIP \
    --priority 1000 \
    --source-address-prefixes $srcaddressprefix \
    --destination-port-ranges '*' \
    --direction Inbound \
    --access Allow \
    --protocol '*' \
    --description "Allow traffic to TCP port any"
}

update_vnet_subnet_nsg() {
  az network vnet subnet update \
    --vnet-name $vnet_name \
    --name $subnet_name \
    --resource-group $rg \
    --network-security-group $nsg_name
}

create_vm() {
  local vm_name_prefix=$1
  local vm_count=$2
  local vm_role=$3 # master or worker

  for ((i=1; i<=vm_count; i++)); do
    local vm_name="${vm_name_prefix}${i}"
    local dns_name="${vm_name_prefix}${i}"
    echo "Creating VM: $vm_name with role: $vm_role and DNS name: $dns_name.$domain"

    az vm create \
      --resource-group $rg \
      --name $vm_name \
      --image $vm_image \
      --size $vm_size \
      --admin-username $admin_username \
      --ssh-key-value "$(cat $ssh_key_path)" \
      --os-disk-size-gb $os_disk_size_gb \
      --location $location \
      --public-ip-sku $public_ip_sku \
      --public-ip-address-dns-name $dns_name \
      --vnet-name $vnet_name \
      --subnet $subnet_name

    # Store VM names for later use
    if [[ "$vm_role" == "master" ]]; then
      master_vm_names+=("$vm_name")
    else
      worker_vm_names+=("$vm_name")
    fi
  done
}

update_nics_with_nsg() {
  local vm_names=("$@") # Accept an array of VM names

  for vm_name in "${vm_names[@]}"; do
    echo "Updating NIC for VM: $vm_name"

    local vnic=$(az vm show --resource-group $rg --name $vm_name --query "networkProfile.networkInterfaces[0].id" -o tsv)
    az network nic update --ids $vnic --network-security-group $nsg_name
  done
}

copy_script_from_master() {
    # Directly use the first master VM name assuming it's the primary one
    local master_vm_name=$1
    local master_dns="${master_vm_name}.${domain}"

    # More secure approach to handle known_hosts entries
    ssh-keygen -f "/home/andy/.ssh/known_hosts" -R "${master_dns}"

    # Copy the script from the master node to the local directory
    scp -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}:${cluster_join_script_name}" .
}


run_script_on_master() {
    local script_path=$1  # Path to the script you want to execute on the master node

    # Assuming only one master node for simplicity
    local master_vm_name="${master_vm_names[0]}"
    local master_dns="${master_vm_name}.${domain}"

    echo "Executing script on master node: $master_dns"
    scp -o "StrictHostKeyChecking=no" "$script_path" "ubuntu@${master_dns}:~/"
    ssh -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}" "bash ~/$(basename $script_path)"
}

run_script_on_workers() {
    local script_path=$1  # Path to the script you want to execute on the worker nodes

    for worker_vm_name in "${worker_vm_names[@]}"; do
        local worker_dns="${worker_vm_name}.${domain}"

        echo "Executing script on worker node: $worker_dns"
        scp -o "StrictHostKeyChecking=no" "$script_path" "ubuntu@${worker_dns}:~/"
        ssh -o "StrictHostKeyChecking=no" "ubuntu@${worker_dns}" "bash ~/$(basename $script_path)"
    done
}

copy_and_modify_kubeconfig() {
    local master_vm_name="${master_vm_names[0]}" # Assuming first master node
    local master_dns="${master_vm_name}.${domain}"
    local local_kubeconfig_path="./config" # Temporary local path for kubeconfig
    local new_kubeconfig_path="$HOME/.kube/config" # Final path for kubeconfig

    # Copy kubeconfig from master node
    echo "Copying kubeconfig from master node: $master_dns"
    scp -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}:/home/ubuntu/.kube/config" $local_kubeconfig_path

    # Modify kubeconfig to use DNS name instead of IP for the server
    echo "Modifying kubeconfig to use DNS name for the server"
    sed -i "s/server: https:\/\/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:6443/server: https:\/\/${master_dns}:6443/g" $local_kubeconfig_path

    # Ensure the .kube directory exists
    mkdir -p "$HOME/.kube"

    # Move modified kubeconfig to the final directory
    echo "Placing modified kubeconfig in $new_kubeconfig_path"
    cp $local_kubeconfig_path $new_kubeconfig_path
}

replace_fqdn_with_master_dns() {

    local file_path=$1  # The file in which to replace the FQDN value
    local master_vm_name="${master_vm_names[0]}" # Assuming the first master node
    local master_dns="${master_vm_name}.${domain}"

    # Check if the file exists
    if [[ ! -f "$file_path" ]]; then
        echo "File $file_path does not exist."
        return 1
    fi

    # Use sed to replace 'FQDN="localhost"' with the master node's DNS name in the file
    sed -i "s/FQDN=\"localhost\"/FQDN=\"${master_dns}\"/g" "$file_path"

    echo "Replaced 'localhost' with '${master_dns}' in $file_path"
}


# Initial setup calls
create_vnet
create_nsg
create_nsg_rule
update_vnet_subnet_nsg
create_vm $master_prefix $number_of_masters "master"
create_vm $worker_prefix $number_of_workers "worker"
update_nics_with_nsg "${master_vm_names[@]}"
update_nics_with_nsg "${worker_vm_names[@]}"
# Assuming 'install_kubeadm_masternode.sh' and 'install_kubeadm_workernode.sh' are located in the current directory
replace_fqdn_with_master_dns "./install_kubeadm_masternode.sh"
run_script_on_master "./install_kubeadm_masternode.sh"
run_script_on_workers "./install_kubeadm_workernode.sh"
copy_script_from_master "${master_vm_names[0]}"
run_script_on_workers "${cluster_join_script_name}" 
copy_and_modify_kubeconfig
