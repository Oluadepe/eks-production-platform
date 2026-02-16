# cert-manager installs certificate automation in-cluster.
# This repo includes it as an SRE maturity component.
#
# NOTE: ALB terminates TLS with ACM certificates. cert-manager is still valuable for:
# - internal mTLS, service-to-service TLS,
# - other ingress controllers (nginx/istio),
# - future enhancements (DNS01 issuance, etc.).

locals {
  cert_manager_namespace    = "cert-manager"
  cert_manager_sa_name      = "cert-manager"
  cert_manager_release_name = "cert-manager"
}

resource "kubernetes_namespace_v1" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0
  metadata { name = local.cert_manager_namespace }
  depends_on = [module.eks]
}

resource "aws_iam_policy" "cert_manager_route53" {
  count       = var.enable_cert_manager ? 1 : 0
  name        = "${var.project}-CertManagerRoute53Policy"
  description = "IAM policy for cert-manager Route53 DNS01 solver"
  policy      = file("${path.module}/iam/cert-manager-route53-policy.json")
}

module "cert_manager_irsa" {
  count   = var.enable_cert_manager ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name_prefix = "${var.project}-cert-manager-"

  role_policy_arns = {
    cm = aws_iam_policy.cert_manager_route53[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.cert_manager_namespace}:${local.cert_manager_sa_name}"]
    }
  }
}

resource "kubernetes_service_account_v1" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0
  metadata {
    name      = local.cert_manager_sa_name
    namespace = local.cert_manager_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.cert_manager_irsa[0].iam_role_arn
    }
  }
  depends_on = [kubernetes_namespace_v1.cert_manager]
}

resource "helm_release" "cert_manager" {
  count      = var.enable_cert_manager ? 1 : 0
  name       = local.cert_manager_release_name
  namespace  = local.cert_manager_namespace
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set { name = "installCRDs"; value = "true" }

  # Use IRSA service account
  set { name = "serviceAccount.create"; value = "false" }
  set { name = "serviceAccount.name"; value = local.cert_manager_sa_name }

  depends_on = [kubernetes_service_account_v1.cert_manager]
}
