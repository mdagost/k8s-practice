#!/bin/bash

# make sure kind is installed; on a mac you can just do brew install kind

# create a local k8s cluster
kind create cluster

# context should be autoset but make sure
kubectl config current-context

# we have to patch coredns so kind can access the internet (via chatgpt)
kubectl patch configmap coredns -n kube-system --type merge -p '{"data":{"Corefile":".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n    }\n    prometheus :9153\n    forward . 8.8.8.8 1.1.1.1 10.48.147.40 10.66.147.40 10.48.147.55 10.48.147.40 10.66.147.40 10.48.147.55 {\n        policy sequential\n        max_fails 1\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'

# build the docker container and push it to the k8s cluster
docker build -t k8s-practice-app ../app/
kind load docker-image k8s-practice-app

# create our namespaces
kubectl create ns dev
kubectl create ns prod

# make sure flux is installed; on a mac you can just do brew install fluxcd/tap/flux
# install the flux helm-controller
docker pull ghcr.io/fluxcd/source-controller:v1.5.0
docker pull ghcr.io/fluxcd/helm-controller:v1.2.0
kind load docker-image ghcr.io/fluxcd/source-controller:v1.5.0
kind load docker-image ghcr.io/fluxcd/helm-controller:v1.2.0
flux install --components=source-controller,helm-controller -v v2.5.1

# apply our helmrepository so flux can find the chart
kubectl apply -f manifests/repo/helmrepository.yaml
# now apply the helmreleases
kubectl apply -f manifests/dev/helmrelease.dev.yaml
kubectl apply -f manifests/prod/helmrelease.prod.yaml

# check that everything started
kubectl get all -n dev
kubectl get all -n prod

# hit the dev service;  should get {"message":"Hello to Michelangelo from dev!!"}
kubectl port-forward svc/dev-helmrelease-k8s-practice-app 8080:80 -n dev
curl localhost:8080/hello

# hit the prod service;  should get {"message":"Hello to Michelangelo from prod!!"}
kubectl port-forward svc/prod-helmrelease-k8s-practice-app 8080:80 -n prod
curl localhost:8080/hello

# clean up
kind delete cluster
