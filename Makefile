CLUSTER_NAME := argocd-vault

# This is what's in the manifest for argocd's overlay
VAULT_SERVICE_ACCOUNT_NAME := argocd-vault-service-account

kind:
	kind create cluster --name $(CLUSTER_NAME)
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

argocd:
	# kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
	kustomize build manifests | kubectl apply -f -

argo-get-pass:
	@echo "ArgoCD Login"
	@echo "=========================="
	@echo "ArgoCD Username is: admin"
	@printf "ArgoCD Password is: %s\n" $$(kubectl -n argocd \
		get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d)
	@echo "=========================="

argo-port-forward: argo-get-pass
	kubectl port-forward svc/argocd-server 8080:80

helm:
	helm repo add hashicorp https://helm.releases.hashicorp.com

vault: helm
	helm install --set ui.enabled=true vault hashicorp/vault

vault-port-forward:
	kubectl port-forward svc/vault-ui 8200:8200

isready:
	echo "TODO fix this"

configure-vault-kubernetes: isready
	CREDS_FILE=$$(find . -name 'vault-cluster-vault*.json'); \
	echo "$$CREDS_FILE"; \
	export VAULT_ADDR=http://localhost:8200; \
	vault login token=$$(jq -r '.root_token' "$$CREDS_FILE"); \
	vault auth enable kubernetes; \
	echo "Configure Vault with the service account jwt"; \
	export VAULT_SA_NAME=$$(kubectl -n default get sa $(VAULT_SERVICE_ACCOUNT_NAME) -o jsonpath="{.secrets[*]['name']}"); \
	export SA_JWT_TOKEN=$$(kubectl -n default get secret $$VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo); \
	export SA_CA_CRT=$$(kubectl -n default get secret $$VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo); \
	export K8S_HOST=$$(kubectl config view -o json | jq '."current-context" as $$context | .clusters[] | select(.name == $$context) | .cluster.server'); \
	vault write auth/kubernetes/config \
		token_reviewer_jwt="$$SA_JWT_TOKEN" \
		kubernetes_host="$$K8S_HOST" \
		kubernetes_ca_cert="$$SA_CA_CRT"

	export VAULT_ADDR=http://localhost:8200; \
	vault write auth/kubernetes/role/argocd \
		bound_service_account_names=$(VAULT_SERVICE_ACCOUNT_NAME) \
		bound_service_account_namespaces=default \
		policies=argocd \
		ttl=1h


deploy: kind argocd vault
