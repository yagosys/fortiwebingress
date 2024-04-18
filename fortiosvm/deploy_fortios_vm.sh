#!/bin/bash -xe
kubectl apply -f cidata.yaml
kubectl apply -f fortiosvmimagedisk.yaml
kubectl apply -f fortiosvminstance.yaml
kubectl apply -f configmap.yaml
kubectl apply -f fortiosvmsvc.yaml

