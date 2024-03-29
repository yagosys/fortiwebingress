#!/bin/bash -x

demoapp1="goweb"
demoapp1image="interbeing/myfmg:goweb"
demoapp1port="80"

demoapp2="nginx"
demoapp2image="nginx"
demoapp2port="80"

nodename="k8strainingmaster001.westus.cloudapp.azure.com"

fortiweblabel="app: fortiweb"
fortiwebcontainerrepo="interbeing/myfmg"
fortiwebcontainerversion="fweb70577"
fortiwebcontainerimage="$fortiwebcontainerrepo:$fortiwebcontainerversion"
fortiwebexposedvipserviceport="8888"

fortiwebingresscontrollerclassname="fortiwebingresscontroller"

fortiwebingresscontrollername="fortiwebingresscontroller"
fortiwebingresscontrollerimage="interbeing/myfmg:fortiwebingresscontrollerx86"
fortiwebingresscontrollernamespace="default"


filename="full_install.yaml"

fortiwebsshusername="admin"
fortiwebsshhost="k8strainingmaster001.westus.cloudapp.azure.com"
fortiwebsshport="2222"
fortiwebsshpassword="Welcome.123"

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
    fortiweblbsvcmetadataannotation="metallb.universe.tf/loadBalancerIPs: $ip"
}
getfortiweblbsvcip
configloadbalanceripifmetallbcontrollerinstalled
