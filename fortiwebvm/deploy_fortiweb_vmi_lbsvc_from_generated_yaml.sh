#!/bin/bash 

azureslbdnslabel="k8strainingmaster1"

function setfortiwebsshhostipifusemetallb() {
if kubectl get ipaddresspools -n metallb-system > /dev/null 2>&1; then
    echo "metallb ippool exist,use cluster master node external ip by default for fortiweb"
#fortiwebsshhost="" && fortiwebsshhost=$(kubectl run curl-ipinfo --image=appropriate/curl --quiet --restart=Never  -it -- curl -s icanhazip.com) && echo $fortiwebsshhost && sleep 2 && kubectl delete pod curl-ipinfo
fortiwebsshhost=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
fortiwebsshhost=$(echo $fortiwebsshhost | awk -F'[/:]' '{print $4}')
else
    fortiwebsshhost=""    
fi

echo "fortiwebsshhost is set to: $fortiwebsshhost"
} 

setfortiwebsshhostipifusemetallb
fortiweblabel="app: fortiweb"
fortiwebcontainerrepo="interbeing/myfmg"
fortiwebcontainerversion="fweb70577"
fortiwebcontainerimage="$fortiwebcontainerrepo:$fortiwebcontainerversion"
fortiwebexposedvipserviceport="8888"

fortiwebsshusername="admin"
fortiwebsshport="2222"
fortiwebsshpassword="Welcome.123"
fortiweblbsvcmetadataannotation=""

filename="fortiweb_vmi_with_disk.yaml"
rm $filename

function getfortiweblbsvcip() {
  if [ -z "$fortiwebsshhost" ]; then
    fortiwebsshhost=$(kubectl get svc $fortiwebcontainerversion-service -o json | jq -r 'select(.spec.selector.app == "fortiweb") | .status.loadBalancer.ingress[0].ip')
  fi
echo $fortiwebsshhost
}

function configloadbalanceripifmetallbcontrollerinstalled() {
    cmd="kubectl get ipaddresspools -n metallb-system -o json"
    ip=$(eval $cmd | jq -r '.items[0].spec.addresses[0]')
    ip=$(echo "$ip" | cut -d'/' -f1)
    # Check if $ip is not empty
    if [ -n "$ip" ]; then
        fortiweblbsvcmetadataannotation="metallb.universe.tf/loadBalancerIPs: $ip"
        echo "Annotation to be applied: $fortiweblbsvcmetadataannotation"
    else
        echo "No IP address retrieved from MetalLB IP address pools."
    fi
}
configloadbalanceripifmetallbcontrollerinstalled
echo $fortiweblbsvcmetadataannotation 

function install_fortiweb_deployment() {
cat << EOF | tee  $filename
---
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  creationTimestamp: null
  generation: 1
  labels:
    kubevirt.io/os: linux
    kubevirt.io/domain: fortiweb
    $fortiweblabel
  name: $fortiwebcontainerversion-deployment
  annotations:
    hooks.kubevirt.io/hookSidecars: '[{"args": ["--version", "v1alpha3"],
      "image": "quay.io/kubevirt/sidecar-shim:20240108_99b6c4bdb",
      "configMap": {"name": "sidecar-script",
                    "key": "my_script.sh",
                    "hookPath": "/usr/bin/preCloudInitIso"}}]'
spec:
  nodeSelector: #nodeSelector matches nodes where performance key has high as value.
    nested: "true"
  domain:
#    ioThreadsPolicy: auto
    cpu:
      cores: 4
    devices:
      blockMultiQueue: true
      disks:
      - disk:
          bus: virtio
        name: disk0
      - disk:
          bus: virtio
        name: disk1
      - disk:
          bus: virtio
        name: data
      - cdrom:
          bus: sata
          readonly: true
        name: cloudinitdisk
    machine:
      type: q35
    resources:
      requests:
        memory: 4096M
  volumes:
  - name: disk0
    persistentVolumeClaim:
      claimName: fortiwebvmimagedisk
  - name: disk1
    persistentVolumeClaim:
      claimName: fortiweblogdisk
  - name: data
    emptyDisk:
      capacity: 8Gi
  - name: cloudinitdisk
    cloudInitNoCloud:
      userData: |
        hostname abc
EOF
}


function expose_fortiweb_loadbalancer_svc() {
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: Service
metadata:
  name: $fortiwebcontainerversion-service
  annotations:
    $fortiweblbsvcmetadataannotation
    service.beta.kubernetes.io/azure-dns-label-name: $azureslbdnslabel
spec:
  externalTrafficPolicy: Local
  sessionAffinity: ClientIP
  ports:
  - port: 18443
    name: webgui
    protocol: TCP
    targetPort: 18443
  - port: $fortiwebsshport
    name: ssh
    protocol: TCP
    targetPort: 22
  - port: $fortiwebexposedvipserviceport
    name: $fortiwebcontainerversion-service-$fortiwebexposedvipserviceport
    targetPort: $fortiwebexposedvipserviceport
  selector:
    kubevirt.io/domain: fortiweb
    $fortiweblabel
  type: LoadBalancer
EOF
}


function create_configmap_for_initcontainer() {
#fortiwebsshhost=$(kubectl get pods -l app=fortiweb -o=jsonpath='{.items[*].status.podIP}')
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-config
data:
  SSH_HOST: "${fortiwebsshhost}"
  SSH_PORT: "${fortiwebsshport}"
  SSH_USERNAME: "${fortiwebsshusername}"
  SSH_NEW_PASSWORD: "${fortiwebsshpassword}"
  FORTIWEBIMAGENAME: "${fortiwebcontainerversion}"
  FORTIWEBSVCPORT:   "${fortiwebexposedvipserviceport}"
EOF
#kubectl apply -f $filename
}

function deploy_from_yaml() {
vminame=$fortiwebcontainerversion-deployment

kubectl apply -f sidecarconfigmapbash.yaml
kubectl apply -f fortiweblogdisk.yaml && \
kubectl apply -f fortiwebvmimagedisk.yaml && \
kubectl apply -f fortiweb_vmi_with_disk.yaml

# Wait for the VM to be in the "Running" state before attempting a reboot
while :; do
    VM_STATUS=$(kubectl get vmi $vminame --output=jsonpath='{.status.phase}')
    if [ "$VM_STATUS" = "Running" ]; then
        echo "VM is now running. Proceeding with soft reboot."
        sleep 120
        virtctl soft-reboot $vminame
        break
    elif [ "$VM_STATUS" = "Failed" ] || [ "$VM_STATUS" = "Succeeded" ]; then
        echo "VM is in a terminal state: $VM_STATUS. Exiting loop."
        break
    else
        echo "Current VM status: $VM_STATUS. Waiting for VM to enter 'Running' state..."
        sleep 10
    fi
done

}
install_fortiweb_deployment
expose_fortiweb_loadbalancer_svc
#kubectl apply -f $filename
#kubectl rollout status deployment $fortiwebcontainerversion-deployment

getfortiweblbsvcip
echo "${fortiwebsshhost}"
create_configmap_for_initcontainer
deploy_from_yaml

