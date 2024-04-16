## create aks node with nested virtualization
```
create_aks_cluster_nestedvm.sh
```

## install kubevirt

```
install_kubevirt.sh
```
## deploy fortiweb vmi with svc
```
deploy_fortiweb_vmi_lbsvc_from_generated_yaml.sh
```

## issues

- after create fortiweb vmi, reboot is required to get correct ip route table

- for web gui access to fortiweb. login to fortiweb to config
``` 
config system global
set admin-sport 18443
```
