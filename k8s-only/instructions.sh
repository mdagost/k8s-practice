#!/bin/bash

# make sure kind is installed; on a mac you can just do brew install kind

# create a local k8s cluster
kind create cluster

# context should be autoset but make sure
kubectl config current-context

# build the docker container and push it to the k8s cluster
docker build -t k8s-practice-app ../app/
kind load docker-image k8s-practice-app

# create our namespaces
kubectl create ns dev
kubectl create ns prod

# apply our k8s manifests
kubectl apply -f manifests/dev/deployment.dev.yaml
kubectl apply -f manifests/dev/service.dev.yaml
kubectl apply -f manifests/prod/deployment.prod.yaml
kubectl apply -f manifests/prod/service.prod.yaml

# check that everything started
kubectl get all -n dev
kubectl get all -n prod

# hit the dev service;  should get {"message":"Hello to Michelangelo from dev!!"}
kubectl port-forward svc/dev-k8s-practice-app 8080:80 -n dev
curl localhost:8080/hello

# hit the prod service;  should get {"message":"Hello to Michelangelo from prod!!"}
kubectl port-forward svc/prod-k8s-practice-app 8080:80 -n prod
curl localhost:8080/hello

# clean up
kind delete cluster
