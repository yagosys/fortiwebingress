#!/bin/bash -x

source ./variable.sh

function install_fortiweb_deployment() {
cat << EOF | tee  $filename
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $fortiwebcontainerversion-deployment
  labels:
    $fortiweblabel
spec:
  replicas: 1
  selector:
    matchLabels:
      $fortiweblabel
  template:
    metadata:
      labels:
        $fortiweblabel
    spec:
      containers:
      - name: $fortiwebcontainerversion-container
        image: $fortiwebcontainerimage
        securityContext:
          privileged: true
        ports:
        - containerPort: 8
        - containerPort: 9
        - containerPort: 43
        - containerPort: 22
        - containerPort: 80
        - containerPort: 443
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
spec:
  sessionAffinity: ClientIP
  ports:
  - port: 2222
    name: ssh
    targetPort: 22
  - port: 18443
    name: gui
    targetPort: 43
  - port: $fortiwebexposedvipserviceport
    name: $fortiwebcontainerversion-service-$fortiwebexposedvipserviceport
    targetPort: $fortiwebexposedvipserviceport
  selector:
    $fortiweblabel
  type: LoadBalancer
EOF
}


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

install_fortiweb_deployment
expose_fortiweb_loadbalancer_svc
install_ingressclass
install_fortiweb_ingresscontroller

