# ArgoCD + Vault basic setup

Set up the basic ArgoCD + Vault instance.

https://ibm.github.io/argocd-vault-plugin/

Using the IBM tutorial, launch argocd with their manifests (they just do a cluster install and install the argocd+vault plugin configmap)

Install Hashicorp Vault using the helm chart.

We are configuring ArgoCD with the K8s Service Account [backend](https://ibm.github.io/argocd-vault-plugin/backends/)
