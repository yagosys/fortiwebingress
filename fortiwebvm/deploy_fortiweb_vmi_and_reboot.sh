kubectl delete -f fortiwebvmsvc.yaml
kubectl delete -f fortiweblogdisk.yaml 
kubectl delete -f fortiwebvmimagedisk.yaml
kubectl delete -f fortiweb_vmi_with_disk.yaml
kubectl delete -f sidecarconfigmapbash.yaml

kubectl apply -f sidecarconfigmapbash.yaml
kubectl apply -f fortiweblogdisk.yaml && \
kubectl apply -f fortiwebvmimagedisk.yaml && \
kubectl apply -f fortiweb_vmi_with_disk.yaml

# Wait for the VM to be in the "Running" state before attempting a reboot
while :; do
    VM_STATUS=$(kubectl get vmi vm1 --output=jsonpath='{.status.phase}')
    if [ "$VM_STATUS" = "Running" ]; then
        echo "VM is now running. Proceeding with soft reboot."
        sleep 120
        virtctl soft-reboot vm1
        break
    elif [ "$VM_STATUS" = "Failed" ] || [ "$VM_STATUS" = "Succeeded" ]; then
        echo "VM is in a terminal state: $VM_STATUS. Exiting loop."
        break
    else
        echo "Current VM status: $VM_STATUS. Waiting for VM to enter 'Running' state..."
        sleep 10
    fi
done

kubectl apply -f fortiwebvmsvc.yaml
