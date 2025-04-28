#!/bin/bash

# make sure kind is installed; on a mac you can just do brew install kind

# create a local k8s cluster
kind create cluster

# context should be autoset but make sure
kubectl config current-context

# build the docker container and push it to the k8s cluster
docker build -t k8s-practice-app ../app/
kind load docker-image k8s-practice-app
# for the helm test
docker pull busybox
kind load docker-image busybox

# create our namespaces
kubectl create ns dev
kubectl create ns prod

# make sure helm is installed; on a mac you can just do brew install helm
# apply our helm chart from the local files
helm upgrade --install k8s-practice-app-dev-release k8s-practice-app/ -f values-dev.yaml
helm upgrade --install k8s-practice-app-prod-release k8s-practice-app/ -f values-prod.yaml

# or apply our helm chart from the remote chart, mimicing a more real-life scenario
helm upgrade --install k8s-practice-app-dev-release https://github.com/mdagost/k8s-practice/raw/refs/heads/main/helm/helm-repo/k8s-practice-app-0.1.0.tgz -f values-dev.yaml
helm upgrade --install k8s-practice-app-prod-release https://github.com/mdagost/k8s-practice/raw/refs/heads/main/helm/helm-repo/k8s-practice-app-0.1.0.tgz -f values-prod.yaml

# check that everything started
kubectl get all -n dev
kubectl get all -n prod

# run the helm tests
helm test --logs k8s-practice-app-dev-release
helm test --logs k8s-practice-app-prod-release

# hit the dev service;  should get {"message":"Hello to Michelangelo from dev!!"}
kubectl port-forward svc/k8s-practice-app-dev-release 8080:80 -n dev
curl localhost:8080/hello

# hit the prod service;  should get {"message":"Hello to Michelangelo from prod!!"}
kubectl port-forward svc/k8s-practice-app-prod-release 8080:80 -n prod
curl localhost:8080/hello

# clean up
kind delete cluster
