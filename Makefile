SHELL := /bin/bash

.PHONY: help init plan apply kubeconfig bootstrap-values deploy helm-up argo-install argo-app monitoring-up status destroy clean

help:
	@echo "Targets:"
	@echo "  init            - terraform init"
	@echo "  plan            - terraform plan"
	@echo "  apply           - terraform apply (creates EKS + controllers)"
	@echo "  kubeconfig      - configure kubectl for the created cluster"
	@echo "  bootstrap-values- generate Helm values (runs terraform apply if needed)"
	@echo "  deploy          - deploy demo app via Helm using generated values"
	@echo "  argo-install    - install Argo CD into cluster"
	@echo "  argo-app        - apply Argo CD Application (GitOps)"
	@echo "  monitoring-up   - install kube-prometheus-stack"
	@echo "  status          - show cluster + app status"
	@echo "  destroy         - terraform destroy (tears down AWS resources)"
	@echo ""
	@echo "Tip: copy terraform/terraform.tfvars.example -> terraform/terraform.tfvars and set your domain/zone first."

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply -auto-approve

kubeconfig:
	@REGION=$$(cd terraform && terraform output -raw region); \
	CLUSTER=$$(cd terraform && terraform output -raw cluster_name); \
	aws eks update-kubeconfig --region $$REGION --name $$CLUSTER; \
	kubectl get nodes

bootstrap-values: apply
	@echo "Generated values at generated/demo-web.values.yaml (from Terraform)."

deploy:
	helm upgrade --install demo-web ./helm/demo-web -f generated/demo-web.values.yaml
	kubectl -n demo get ingress demo-web || true

argo-install:
	kubectl create namespace argocd || true
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl -n argocd rollout status deploy/argocd-server

argo-app:
	kubectl apply -f argocd/application.yaml

monitoring-up:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
	  -n monitoring --create-namespace -f monitoring/kube-prometheus-stack-values.yaml

status:
	kubectl get nodes
	kubectl -n kube-system get deploy | head -n 20
	kubectl -n demo get deploy,svc,ingress || true
	kubectl -n argocd get pods || true
	kubectl -n external-dns get pods || true
	kubectl -n cert-manager get pods || true

destroy:
	cd terraform && terraform destroy -auto-approve

clean:
	rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate* generated/demo-web.values.yaml || true
