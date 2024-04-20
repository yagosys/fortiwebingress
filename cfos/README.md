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
# scale fortiweb
since the configuration are saved on host


```
 kubectl scale deployment fweb70577-deployment --replicas=2
```