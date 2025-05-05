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

# apply our manifests
kubectl apply -k overlays/dev/
kubectl apply -k overlays/prod/

# check that everything started
kubectl get all -n dev
kubectl get all -n prod

# hit the dev service;  should get {"message":"Hello to Michelangelo from dev!!"}
kubectl port-forward svc/k8s-practice-app-dev 8080:80 -n dev
curl localhost:8080/hello

# hit the prod service;  should get {"message":"Hello to Michelangelo from prod!!"}
kubectl port-forward svc/k8s-practice-app-prod 8080:80 -n prod
curl localhost:8080/hello

# clean up
kind delete cluster
