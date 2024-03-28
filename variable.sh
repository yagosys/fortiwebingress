#!/bin/bash -x

demoapp1="goweb"
demoapp1image="ttl.sh/goweb:1h"
demoapp1port="80"

demoapp2="nginx"
demoapp2image="nginx"
demoapp2port="80"

nodename="k8strainingmaster001.westus.cloudapp.azure.com"

fortiweblabel="app: fortiweb"
fortiwebcontainerrepo="interbeing/myfmg"
fortiwebcontainerversion="fweb70577"
fortiwebcontainerimage="$fortiwebcontainerversion"
fortiwebexposedvipserviceport="8888"

fortiwebingresscontrollerclassname="fortiwebingresscontroller"

fortiwebingresscontrollername="fortiwebingresscontrollerx86"
fortiwebingresscontrollerimage="ttl.sh/fortiwebingresscontrollerx86:2h"
fortiwebingresscontrollernamespace="default"

filename="full_install.yaml"

function configloadbalanceripifmetallbcontrollerinstalled() {
    cmd="kubectl get ipaddresspools -n metallb-system -o json"
    ip=$(eval $cmd | jq -r '.items[0].spec.addresses[0]')
    ip=$(echo "$ip" | cut -d'/' -f1)
    fortiweblbsvcmetadataannotation="metallb.universe.tf/loadBalancerIPs: $ip"
}

configloadbalanceripifmetallbcontrollerinstalled
