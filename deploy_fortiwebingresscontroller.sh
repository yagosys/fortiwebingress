#!/bin/bash 

if kubectl get ipaddresspools -n metallb-system > /dev/null 2>&1; then
    echo "metallb ippool exist,  Please enter the value for fortiwebsshhost (default: k8strainingmaster001.westus.cloudapp.azure.com): "
    echo "please input host name or ip within 30 seconds"
    read -r -t 30 -p "" input
    fortiwebsshhost=${input:-k8strainingmaster001.westus.cloudapp.azure.com}
else
    fortiwebsshost=""
fi

echo "fortiwebsshhost is set to: $fortiwebsshhost"

fortiwebingresscontrollerclassname="fortiwebingresscontroller"

fortiwebingresscontrollername="fortiwebingresscontroller"
fortiwebingresscontrollerimage="interbeing/myfmg:fortiwebingresscontrollerx86"
fortiwebingresscontrollernamespace="default"

filename="deploy_fortiwebingresscontroller.yaml"
rm $filename

fortiwebsshusername="admin"
fortiwebsshport="2222"
fortiwebsshpassword="Welcome.123"

fortiwebcontainerversion="fweb70577"

function getfortiweblbsvcip() {
  if [ -z "$fortiwebsshhost" ]; then
    fortiwebsshhost=$(kubectl get svc $fortiwebcontainerversion-service -o json | jq -r 'select(.spec.selector.app == "fortiweb") | .status.loadBalancer.ingress[0].ip')
  fi
echo $fortiwebsshhost
}

getfortiweblbsvcip



function install_ingressclass() {
cat << EOF | tee -a $filename
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: $fortiwebingresscontrollername
spec:
  controller: yagosys.com/ingresscontroller
EOF
}

function install_fortiweb_ingresscontroller() {
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-$fortiwebingresscontrollername
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $fortiwebingresscontrollername
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $fortiwebingresscontrollername
  template:
    metadata:
      labels:
        app: $fortiwebingresscontrollername
    spec:
      serviceAccountName: sa-$fortiwebingresscontrollername
      initContainers:
      - name: ssh-setup
        image: interbeing/myfmg:my-ssh-setup-image
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: ssh-config
      containers:
      - name: $fortiwebingresscontrollername
        image: $fortiwebingresscontrollerimage
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: ssh-config
        ports:
        - containerPort: 80
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: $fortiwebingresscontrollername-role
rules:
- apiGroups: ["", "extensions", "networking.k8s.io"]
  resources: ["ingresses", "services", "endpoints", "pods", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $fortiwebingresscontrollername-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $fortiwebingresscontrollername-role
subjects:
- kind: ServiceAccount
  name: sa-$fortiwebingresscontrollername
  namespace: $fortiwebingresscontrollernamespace
EOF
}

function create_configmap_for_initcontainer() {
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
EOF
}
install_ingressclass
install_fortiweb_ingresscontroller
create_configmap_for_initcontainer
kubectl apply -f $filename
kubectl rollout status deployment $fortiwebingresscontrollername