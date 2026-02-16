# EKS Production Platform (Terraform + GitOps + Monitoring)

## Version
- **v1.2.4** (Generated 2026-02-14)
  - Added `make all` target for end-to-end provisioning + deploy + status
  - Keeps v1.2.3: Makefile, tfvars example, GitOps-ready Argo CD + generated Helm values








A production-style platform repo that provisions an AWS EKS cluster and deploys workloads using GitOps practices (Argo CD), with an optional monitoring stack (Prometheus/Grafana). This is designed as a portfolio project that mirrors real-world DevOps/SRE patterns: IaC, repeatable environments, secure access, and operable workloads.

---

## Architecture

![Architecture](docs/architecture.png)

### Component Overview

- **Terraform (IaC)** provisions:
  - **VPC** with public + private subnets and NAT gateway
  - **EKS Cluster** (managed control plane) in **private subnets**
  - **Managed Node Group** for worker nodes (autoscaling configuration)
  - **IRSA role** for the **EBS CSI driver** (principle of least privilege)
  - Optional **aws-auth** mappings for additional admin roles

- **Ingress + Load Balancing**
  - The sample ingress is annotated for the **AWS Load Balancer Controller (ALB)**.
  - This creates an **Application Load Balancer** that routes traffic to Kubernetes Services.

- **GitOps (Argo CD)**
  - Argo CD continuously reconciles cluster state with your Git repository.
  - You deploy by committing changes to Git—Argo CD applies them.

- **Monitoring (Prometheus/Grafana)**
  - Uses the **kube-prometheus-stack** Helm chart as a common industry standard.
  - Prometheus scrapes metrics; Grafana visualizes dashboards and alerts.

---

## Repository Layout

```text
eks-production-platform/
├── terraform/                       # VPC + EKS + IAM (IRSA)
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── iam-ebs-csi.tf
│   ├── aws-auth.tf                  # optional admin role mapping
│   └── outputs.tf
├── kubernetes/                      # sample app manifests (Kustomize-ready)
│   ├── 00-namespace.yaml
│   ├── 10-deployment.yaml
│   ├── 20-service.yaml
│   ├── 30-ingress.yaml
│   └── kustomization.yaml
├── argocd/
│   └── application.yaml             # Argo CD Application definition
├── monitoring/
│   └── kube-prometheus-stack-values.yaml
├── docs/
│   └── architecture.png             # diagram
└── .github/workflows/
    └── terraform-plan-apply.yml     # optional CI pipeline template
```

---


## DNS + TLS Configuration (v1.2.0)

This version adds **three production-grade capabilities**:

1) **TLS (HTTPS) on ALB using ACM**
2) **ExternalDNS** for Route53 auto-DNS updates
3) **cert-manager** for certificate automation (Route53 DNS01)

### Required inputs for full automation
To make everything work end-to-end you need:
- A Route53 hosted zone for your domain (e.g., `example.com`)
- The hosted zone ID (e.g., `Z123...`)

### Option A: Use an existing ACM certificate (most common)
1. Create/validate an ACM certificate manually in the **same region** as your cluster/ALB.
2. Set `acm_certificate_arn` in Terraform (or directly in the ingress annotations).
3. Update the ingress annotations:
   - `alb.ingress.kubernetes.io/certificate-arn`
   - `external-dns.alpha.kubernetes.io/hostname`
   - `spec.rules.host`

### Option B: Let Terraform request/validate ACM automatically
In `terraform/variables.tf`, set:
- `create_acm_certificate = true`
- `route53_zone_id = "Z123..."`
- `demo_hostname = "demo.example.com"`

Then run:
```bash
cd terraform
terraform apply -auto-approve
```

After apply, get the certificate ARN:
```bash
terraform output -raw effective_acm_certificate_arn
```

### ExternalDNS (Route53)
ExternalDNS is installed by Terraform (IRSA + Helm). It watches your cluster and automatically creates:
- `demo.example.com -> ALB DNS name`

You must set:
- `domain_name`
- (recommended) `route53_zone_id`

### cert-manager
cert-manager is installed by Terraform. Sample manifests are in `cert-manager/`:
- `cert-manager/clusterissuer-route53.yaml`
- `cert-manager/certificate-demo.yaml`

Apply them after install:
```bash
kubectl apply -f cert-manager/clusterissuer-route53.yaml
kubectl apply -f cert-manager/certificate-demo.yaml
```

> Important: ALB terminates TLS using ACM. cert-manager is included as an SRE maturity add-on (useful for internal TLS/mTLS and future ingress controllers).


## Prerequisites

### Local tools
- **Terraform** >= 1.6
- **AWS CLI** v2
- **kubectl**
- **Helm** (recommended)
- (Optional) **kustomize**

### AWS requirements
- An AWS account with permissions to create:
  - VPC, subnets, route tables, NAT gateway
  - EKS cluster and managed node groups
  - IAM roles/policies
  - (Optional) ALB resources via AWS Load Balancer Controller

---

## Quick Start (End-to-End)

### One-command end-to-end (v1.2.4)
After setting `terraform/terraform.tfvars`, run:

```bash
make all
```

This will:
- provision AWS infra (EKS + controllers)
- configure your kubeconfig
- deploy the demo app via Helm (generated values)
- show status for key namespaces


### 1) Configure AWS credentials
Set up AWS auth (pick one):
- `aws configure` (access keys), OR
- SSO, OR
- Role-based auth in a corporate environment

Verify:
```bash
aws sts get-caller-identity
```

### 2) Provision infrastructure with Terraform
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 3) Connect kubectl to the cluster
```bash
REGION=$(terraform output -raw region)
CLUSTER=$(terraform output -raw cluster_name)

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes
```

---

## Zero-manual-edit deploy (v1.2.2) — Terraform generates Helm values

This is the easiest way to deploy **without editing any YAML**.

### 1) Set your DNS + TLS inputs (Terraform)
In `terraform/terraform.tfvars` (create it), set at least:
```hcl
domain_name      = "example.com"
demo_hostname    = "demo.example.com"
route53_zone_id  = "Z1234567890ABCDE"   # your hosted zone id
create_acm_certificate = true           # Terraform will request + validate ACM for demo_hostname
```

Then apply:
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2) Use the generated Helm values
Terraform writes:
- `generated/demo-web.values.yaml`

Deploy the app with:
```bash
helm upgrade --install demo-web ./helm/demo-web -f generated/demo-web.values.yaml
```

### 3) Verify HTTPS + DNS
```bash
kubectl -n demo get ingress demo-web
```
- Ingress should show an **ADDRESS** (ALB DNS name).
- Route53 should get `demo.example.com` automatically via ExternalDNS.
- If ACM was created/validated, ALB will serve **HTTPS**.

> GitOps tip: Commit `generated/demo-web.values.yaml` into your repo and reference it from Argo CD for a truly hands-off workflow.


## Deploy the Sample App (Two Ways)

## Deploy the Sample App (Helm - Recommended)

This is the **plug-and-play** way to deploy. You set the hostname and (optionally) the ACM certificate ARN in `helm/demo-web/values.yaml` or via `--set`.

### 1) Get the ACM certificate ARN (if using Terraform-managed ACM)
If you enabled `create_acm_certificate = true`, you can fetch the effective ARN:
```bash
terraform -chdir=terraform output -raw effective_acm_certificate_arn
```

### 2) Install the chart
```bash
helm upgrade --install demo-web ./helm/demo-web --create-namespace
```

### 3) Override hostname and ACM ARN (recommended)
```bash
helm upgrade --install demo-web ./helm/demo-web   --set ingress.hostname=demo.example.com   --set ingress.tls.acmCertificateArn=arn:aws:acm:REGION:ACCOUNT:certificate/XXXX
```

### 4) Verify
```bash
kubectl -n demo get deploy,svc,ingress
kubectl -n demo get ingress demo-web
```

Within a few minutes you should see an **ADDRESS** (ALB DNS name). If ExternalDNS is configured, Route53 will get a record for your hostname.



### Option A: Direct `kubectl apply` (fast)
```bash
kubectl apply -f kubernetes/
kubectl -n demo get deploy,svc,ingress
```

### Option B: GitOps via Argo CD (recommended)

#### 1) Install Argo CD
```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

#### 2) Expose Argo CD UI (development only)
Use port-forwarding:
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```
Open: `https://localhost:8080`

Get initial password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret   -o jsonpath="{.data.password}" | base64 -d; echo
```

#### 3) Configure the Argo CD Application
Edit `argocd/application.yaml` and replace:
- `repoURL: https://github.com/YOUR_GITHUB_USERNAME/eks-production-platform.git`

Then apply:
```bash
kubectl apply -f argocd/application.yaml
```

Argo CD will sync the manifests under `kubernetes/` automatically.

---

## Ingress / ALB Setup (ALB is installed automatically)

This repo **installs the AWS Load Balancer Controller automatically via Terraform** using:
- **IRSA** (IAM role for service account)
- Helm chart: `aws-load-balancer-controller`

After `terraform apply`, you can deploy the sample ingress:

```bash
kubectl apply -f kubernetes/
kubectl -n demo get ingress
```

Within a few minutes, the ingress should show an **ADDRESS** (the ALB DNS name):

```bash
kubectl -n demo get ingress demo-web
```

### Notes
- The ingress class used is `alb` (`kubernetes.io/ingress.class: alb`).
- Ensure your public subnets are tagged correctly (Terraform VPC module adds the standard EKS tags).
- If you deploy in a region with fewer than 3 AZs available, adjust subnet lists and AZ slicing.


## Monitoring (Prometheus + Grafana)

Install `kube-prometheus-stack` with the included starter values:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack   -n monitoring --create-namespace   -f monitoring/kube-prometheus-stack-values.yaml
```

Verify:
```bash
kubectl -n monitoring get pods
```

Access Grafana (dev only):
```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```
Open: `http://localhost:3000`

Default username: `admin`  
Password: set in `monitoring/kube-prometheus-stack-values.yaml` (change it).

---

## Security Notes (What makes this “production-style”)

- **Private subnets** for worker nodes
- **IRSA** for service accounts (example: EBS CSI driver)
- Encourages least-privilege IAM rather than static node credentials
- Separation of concerns:
  - Terraform provisions infra
  - GitOps manages application state
  - Monitoring provides observability

---

## Troubleshooting

### Terraform apply fails (permissions)
Confirm your AWS identity and permissions:
```bash
aws sts get-caller-identity
```

### kubectl cannot connect
Re-run kubeconfig command:
```bash
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
```

### Ingress has no address
Most common cause: AWS Load Balancer Controller not installed or misconfigured.

---

## Full GitOps workflow (v1.2.3)

Because Argo CD pulls from Git, it can only use files that exist **in your repo**.

### 1) Configure inputs (one time)
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars with your domain/zone details
```

### 2) Provision infra + generate values
```bash
make bootstrap-values
```
Terraform will write:
- `generated/demo-web.values.yaml`

### 3) Commit generated values (required for GitOps)
```bash
git add generated/demo-web.values.yaml
git commit -m "Add generated demo-web values (hostname + ACM ARN)"
git push
```

### 4) Install Argo CD and apply the app
```bash
make argo-install
# edit argocd/application.yaml repoURL to your repo, then:
make argo-app
```

Argo CD will deploy the Helm chart using:
- `helm/demo-web/values.yaml` (defaults)
- `generated/demo-web.values.yaml` (your hostname + TLS settings)

### One-command non-GitOps deploy (still useful)
```bash
make deploy
```


## Cleanup (Avoid AWS Costs)
```bash
cd terraform
terraform destroy -auto-approve
```

---

## Next Improvements (Great for portfolio)
- Add AWS Load Balancer Controller install via Terraform+Helm
- Add a real microservice (Python/Go) + Helm chart
- Add canary/blue-green deployments
- Add SLOs, alerts, and incident runbooks
- Add OIDC-based GitHub Actions deploy role for CI/CD
