# Option 1 - Deploy k8s cluster

```
create_kubeadm_k8s_on_ubuntu22.sh
```

# Install metallb loadbalancer with local pool

```
ingressmetallbforkubeadmk8s.sh
```

# Optino 2 - Deploy AKS

```
create_aks_cluster_nestedvm.sh
```

# Deploy cfos

## Create Role for cfos 
cfos need permission to read configmap and secret 

```
kubectl apply -f 04_cfos_account.yml 
```
## Create cfos license 

```
kubectl apply -f cfos_license.yaml
```

## Create docker pull secret

the cfos image is on private repo which require use credential to retrive it

```
kubectl apply -f dockerinterbeing.yaml 
```

## Deploy cfos deployment

cfos will save configuration and license on /data which is mounted on host 
```
kubectl apply -f deploy_fortiweb_deployment.yaml
```

## Check the deployment result

```
kubectl logs -f po/`k get pod -l app=fortiweb | grep Running  | tail -n 1 | cut -d ' ' -f 1` 

System is starting...

Firmware version is 7.2.1.0250
Preparing environment...
Verifying license...
INFO: 2024/04/19 08:46:27 importing license...
INFO: 2024/04/19 08:46:27 license is imported successfuly!
WARNING: System is running in restricted mode due to lack of valid license!
Starting services...
System is ready.

2024-04-19_08:46:32.58092 ok: run: /etc/services/certd: (pid 129) 6s, normally down
2024-04-19_08:46:37.62151 INFO: 2024/04/19 08:46:37 received a new fos configmap
2024-04-19_08:46:37.62152 INFO: 2024/04/19 08:46:37 configmap name: fos-license, labels: map[app:fos category:license]
2024-04-19_08:46:37.62152 INFO: 2024/04/19 08:46:37 got a fos license
```
# Deploy demo application and create clusterip service  

this demo application will be the backend application 

```
kubectl apply -f demoapp.yaml
kubectl expose deployment multitool01-deployment --port 80
```
### Check backend svc ip
```
backendip=$(k get svc -l app=multitool01 -o json | jq -r .items[].spec.clusterIP)
echo $backendip

```

# Deploy cfos lb service

```
 kubectl apply -f deploy_fortiweb_lb_svc.yaml
```
# option 1 - Create configuration for cfos

```
create_configmap_for_cfos.sh
```

then check the yml file created by script. and apply it

```
kubectl apply -f demoservicecm.yml 
```
# option 2 - use cfos controller 

```
kubectl apply -f deploy_cfoscontroller.yaml
```

## Check the cfos configuration and log

```
kubectl logs -f po/`k get pod -l app=fortiweb | grep Running  | tail -n 1 | cut -d ' ' -f 1`
```

# Verify the result

```
curl http://k8strainingmaster1.westus.cloudapp.azure.com:8888

```
## Check cfos traffic log

```
kubectl exec -it po/`k get pod -l app=fortiweb | grep Running  | tail -n 1 | cut -d ' ' -f 1` -- sh -c 'more /var/log/log/traffic.0'
```
# Demo virus scan 

## create demo application 
```
create_demo_file_upload_application_svc.sh
```

## modify protected application to goweb

```
kubectl edit svc fweb70577-service
```
then modify annotation to 
```
protectedClusterIPSVCName: goweb
```
##  check result

cfoscontroller will automatically update backend application 
```
kubectl logs -f po/`k get pod -l app=cfoscontrolleramd64alpha1 | grep Running  | tail -n 1 | cut -d ' ' -f 1`
```
result will be 

```
found annotation protectedClusterIPSVCName with value gowebget service fweb70577-service endpoint with ip = 10.224.0.16 and Port = 8888 
get service goweb with ClusterIP= 10.96.195.4 and Port = 80 
%!(EXTRA string=80)PrepareVIPConfigMap %s cfoscmvip
ConfigMap cfoscmvip already exists, updating it
ConfigMap Updated Successfully
take value for service fweb70577-service in namespace default
set ServiceName=service8888, TcpPortRange=8888PrepareServiceConfigMap %s cfoscmservice
ConfigMap cfoscmservice already exists, updating it
ConfigMap Updated Successfully
take value for service fweb70577-service in namespace default
PreparePolicyConfigMap %s cfoscmpolicy
ConfigMap cfoscmpolicy already exists, updating it
ConfigMap Updated Successfully
```
# demo file upload

```
http://k8strainingmaster1.westus.cloudapp.azure.com:8888/upload
```
then upload "eicarcom2.zip" , cfos will block the upload

## check log 
```
kubectl exec -it po/`k get pod -l app=fortiweb | grep Running  | tail -n 1 | cut -d ' ' -f 1` -- sh -c 'more /var/log/log/virus.0'
```
result will be 
```
date=2024-04-20 time=12:30:48 eventtime=1713616248 tz="+0000" logid="0211008192" type="utm" subtype="virus" eventtype="infected" level="warning" policyid=3 msg="File is infected." action="blocked" service="HTTP" sessionid=616 srcip=10.224.0.4 dstip=10.96.195.4 srcport=24579 dstport=80 srcintf="eth0" dstintf="eth0" proto=6 direction="outgoing" filename="eicarcom2.zip" checksum="45a2cdd" quarskip="No-skip" virus="EICAR_TEST_FILE" dtype="Virus" ref="http://www.fortinet.com/ve?vn=EICAR_TEST_FILE" virusid=2172 url="http://k8strainingmaster1.westus.cloudapp.azure.com/upload" profile="default" agent="Chrome/120.0.0.0" analyticscksum="e1105070ba828007508566e28a2b8d4c65d192e9eaf3b7868382b7cae747b397" analyticssubmit="false"
```
# scale fortiweb
since the configuration are saved on host


```
 kubectl scale deployment fweb70577-deployment --replicas=2
```
