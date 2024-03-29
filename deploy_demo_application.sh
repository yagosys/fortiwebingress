#!/bin/bash -x

demoapp1="goweb"
demoapp1image="interbeing/myfmg:goweb"
demoapp1port="80"

demoapp2="nginx"
demoapp2image="nginx"
demoapp2port="80"

function deploy_application_deployment() {
kubectl create deployment $demoapp1 --image=$demoapp1image
kubectl rollout status deployment $demoapp1
kubectl create deployment $demoapp2 --image=$demoapp2image
kubectl rollout status deployment $demoapp2
}

function deploy_application_clusterIPSVC() {
kubectl expose deployment $demoapp1 --port=$demoapp1port
kubectl expose deployment $demoapp2 --port=$demoapp2port
}

function demo() {
curl http://$nodename:$fortiwebexposedvipserviceport/v2
curl http://$nodename:$fortiwebexposedvipserviceport/index.html
}
deploy_application_deployment
deploy_application_clusterIPSVC

