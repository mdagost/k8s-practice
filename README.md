# k8s-practice

**Deploy the same simple app using multiple k8s deployment methods!  For the learning.**

1. Glance at the app code in `/app`.
2. Deploy using bare k8s manifests: `/k8s-only`
3. Layer on kustomize to avoid code duplication: `/kustomize`
4. Bundle into a helm chart that can be deployed with different values: `/helm`
5. Use flux to deploy the helm chart via a helmrelease: `/helmrelease`
6. Layer on kustomize to avoid duplicative helmrelease files: `/helmrelease-kustomize`
7. Deploy all the above apps with infrastructure-as-code using argo: `/argo`
