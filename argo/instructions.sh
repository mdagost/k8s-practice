#!/bin/bash

# make sure kind is installed; on a mac you can just do brew install kind

# create a local k8s cluster
kind create cluster

# context should be autoset but make sure
kubectl config current-context

# we have to patch coredns so kind can access the internet (via chatgpt)
kubectl patch configmap coredns -n kube-system --type merge -p '{"data":{"Corefile":".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n    }\n    prometheus :9153\n    forward . 8.8.8.8 1.1.1.1 10.48.147.40 10.66.147.40 10.48.147.55 10.48.147.40 10.66.147.40 10.48.147.55 {\n        policy sequential\n        max_fails 1\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'

# make sure the argo cli is installed; on a mac you can just do brew install argocd
# install argo on the cluster
docker pull quay.io/argoproj/argocd:v2.14.11
docker pull redis:7.0.15-alpine
docker pull ghcr.io/dexidp/dex:v2.41.1
kind load docker-image quay.io/argoproj/argocd:v2.14.11
kind load docker-image redis:7.0.15-alpine
kind load docker-image ghcr.io/dexidp/dex:v2.41.1
kubectl create namespace argocd
# download the argo manifest...
curl -LO https://raw.githubusercontent.com/argoproj/argo-cd/refs/tags/v2.14.11/manifests/install.yaml
# ...and patch it so it works with kind
sed -i '' 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/g' install.yaml
kubectl apply -n argocd -f install.yaml
rm -f install.yaml

# make sure flux is installed; on a mac you can just do brew install fluxcd/tap/flux
# install the flux helm-controller
docker pull ghcr.io/fluxcd/source-controller:v1.5.0
docker pull ghcr.io/fluxcd/helm-controller:v1.2.0
kind load docker-image ghcr.io/fluxcd/source-controller:v1.5.0
kind load docker-image ghcr.io/fluxcd/helm-controller:v1.2.0
flux install --components=source-controller,helm-controller -v v2.5.1

# argocd username is admin and password can be retrieved with
argocd admin initial-password -n argocd
# visit the argo UI http://localhost:8080
kubectl port-forward svc/argocd-server -n argocd 8080:443
# use that same password to login to the cluster
argocd login localhost:8080 --insecure --grpc-web

# add our cluster to argo; note that --in-cluster flag only came after an hour
# of debugging with 4o and then finally switching to o3, which
# explained it https://chatgpt.com/share/6816b9b9-e1bc-8003-9fa8-8ecabf4cda29
argocd cluster add kind-kind --in-cluster

# build the docker container and push it to the k8s cluster
docker build -t k8s-practice-app ../app/
kind load docker-image k8s-practice-app

# create our namespaces
kubectl create ns dev
kubectl create ns prod

# create our applications
############
# k8s only #
############
argocd app create k8s-only --repo https://github.com/mdagost/k8s-practice.git --path k8s-only/manifests/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app sync argocd/k8s-only
# delete the app in the UI or
argocd app delete k8s-only --cascade --propagation-policy=foreground -y

#############
# kustomize #
#############
argocd app create kustomize-dev --repo https://github.com/mdagost/k8s-practice.git --path kustomize/overlays/dev/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app create kustomize-prod --repo https://github.com/mdagost/k8s-practice.git --path kustomize/overlays/prod/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app sync argocd/kustomize-dev
argocd app sync argocd/kustomize-prod
# delete the app in the UI or
argocd app delete kustomize-dev --cascade --propagation-policy=foreground -y
argocd app delete kustomize-prod --cascade --propagation-policy=foreground -y

########
# helm #
########
argocd app create helm-dev --repo https://github.com/mdagost/k8s-practice.git --path helm/k8s-practice-app/ --dest-server https://kubernetes.default.svc --dest-namespace default --values ../values.dev.yaml
argocd app create helm-prod --repo https://github.com/mdagost/k8s-practice.git --path helm/k8s-practice-app/ --dest-server https://kubernetes.default.svc --dest-namespace default --values ../values.prod.yaml
argocd app sync argocd/helm-dev
argocd app sync argocd/helm-prod
# delete the app in the UI o
argocd app delete helm-dev --cascade --propagation-policy=foreground -y
argocd app delete helm-prod --cascade --propagation-policy=foreground -y

###############
# helmrelease #
###############
argocd app create helmrelease --repo https://github.com/mdagost/k8s-practice.git --path helmrelease/manifests/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app sync argocd/helmrelease
# delete the app in the UI or
argocd app delete helmrelease --cascade --propagation-policy=foreground -y

###########################
# helmrelease + kustomize #
###########################
# create the helm repository
argocd app create helmrelease-kustomize-repo --repo https://github.com/mdagost/k8s-practice.git --path helmrelease-kustomize/manifests/ --dest-server https://kubernetes.default.svc --dest-namespace default
rver https://kubernetes.default.svc --dest-namespace default
argocd app create helmrelease-kustomize-dev --repo https://github.com/mdagost/k8s-practice.git --path helmrelease-kustomize/overlays/dev/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app create helmrelease-kustomize-prod --repo https://github.com/mdagost/k8s-practice.git --path helmrelease-kustomize/overlays/prod/ --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app sync argocd/helmrelease-kustomize-repo
argocd app sync argocd/helmrelease-kustomize-dev
argocd app sync argocd/helmrelease-kustomize-prod
# delete the app in the UI or
argocd app delete helmrelease-kustomize-repo --cascade --propagation-policy=foreground -y
argocd app delete helmrelease-kustomize-dev --cascade --propagation-policy=foreground -y
argocd app delete helmrelease-kustomize-prod --cascade --propagation-policy=foreground -y

# check that everything started
kubectl get all -n dev
kubectl get all -n prod

# hit the dev service;  should get {"message":"Hello to Michelangelo from dev!!"}
kubectl port-forward svc/k8s-practice-app 8081:80 -n dev
curl localhost:8081/hello

# hit the prod service;  should get {"message":"Hello to Michelangelo from prod!!"}
kubectl port-forward svc/k8s-practice-app 8081:80 -n prod
curl localhost:8081/hello

# clean up
kind delete cluster
