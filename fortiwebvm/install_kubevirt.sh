#!/bin/bash -xe
#if sudo pwd ; then echo you are sudoer; fi

export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | sort -r | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
echo $VERSION
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml

kubectl rollout status deployment -n kubevirt && 
kubectl rollout status ds -n kubevirt && 
kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}"

while true; do
  PHASE=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o jsonpath="{.status.phase}")
  if [ "$PHASE" == "Deployed" ]; then
    break
  else
    echo "Waiting for status.phase to become Deployed, current phase: $PHASE"
    sleep 10
  fi
done
echo "Status.phase is now Deployed"


function install_virtctl() {
echo  install virtcl client  
#export KUBEVIRT_VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest | jq -r .tag_name)
export KUBEVIRT_VERSION=$VERSION
mkdir -p ~/bin
wget -O ~/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/virtctl-${KUBEVIRT_VERSION}-linux-amd64
chmod +x ~/bin/virtctl
#sudo install ~/virtctl /usr/local/bin
}
#install_virtctl
echo install krew
function install_krew (){
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install virt
}
#install_krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH" >> ~/.bashrc
echo export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH" >> ~/.bashrc
source ~/.bashrc



#echo #install localhost storageclass
#kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
#kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
#kubectl rollout status deployment/local-path-provisioner  -n local-path-storage


echo  intall data importor 
export VERSION=$(curl -Ls https://github.com/kubevirt/containerized-data-importer/releases/latest | grep -m 1 -o "v[0-9]\.[0-9]*\.[0-9]*")
echo $VERSION
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml && 
kubectl -n cdi scale deployment/cdi-operator --replicas=1 && 
kubectl -n cdi rollout status deployment/cdi-operator 

echo - install crd for cdi 
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml
kubectl wait -n cdi --for=jsonpath='{.status.phase}'=Deployed cdi/cdi --timeout=600s && 
kubectl -n cdi get pods
sleep 10 

#kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}'

function enable_feature_gate() {
cat << EOF | kubectl apply -f -
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  configuration:
    developerConfiguration: 
      featureGates:
        - Sidecar
EOF
}
enable_feature_gate
echo deploymentcompleted
