# ExternalDNS (Route53) installs and manages DNS records from Kubernetes resources (Ingress/Service).
# This enables: demo.example.com -> ALB automatically.

locals {
  external_dns_namespace    = "external-dns"
  external_dns_sa_name      = "external-dns"
  external_dns_release_name = "external-dns"
}

resource "kubernetes_namespace_v1" "external_dns" {
  count = var.enable_external_dns ? 1 : 0
  metadata { name = local.external_dns_namespace }
  depends_on = [module.eks]
}

resource "aws_iam_policy" "external_dns" {
  count       = var.enable_external_dns ? 1 : 0
  name        = "${var.project}-ExternalDNSPolicy"
  description = "IAM policy for ExternalDNS (Route53)"
  policy      = file("${path.module}/iam/external-dns-policy.json")
}

module "external_dns_irsa" {
  count   = var.enable_external_dns ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name_prefix = "${var.project}-external-dns-"

  role_policy_arns = {
    extdns = aws_iam_policy.external_dns[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.external_dns_namespace}:${local.external_dns_sa_name}"]
    }
  }
}

resource "kubernetes_service_account_v1" "external_dns" {
  count = var.enable_external_dns ? 1 : 0
  metadata {
    name      = local.external_dns_sa_name
    namespace = local.external_dns_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns_irsa[0].iam_role_arn
    }
  }
  depends_on = [kubernetes_namespace_v1.external_dns]
}

resource "helm_release" "external_dns" {
  count      = var.enable_external_dns ? 1 : 0
  name       = local.external_dns_release_name
  namespace  = local.external_dns_namespace
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"

  set { name = "provider"; value = "aws" }
  set { name = "aws.region"; value = var.region }

  # Use service account with IRSA
  set { name = "serviceAccount.create"; value = "false" }
  set { name = "serviceAccount.name"; value = local.external_dns_sa_name }

  # Recommended registry/policy
  set { name = "policy"; value = "upsert-only" }
  set { name = "registry"; value = "txt" }
  set { name = "txtOwnerId"; value = var.project }

  # Constrain to your domain if provided
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }

  # Optionally constrain to a single zone (preferred in multi-zone accounts)
  dynamic "set" {
    for_each = var.route53_zone_id != "" ? [1] : []
    content {
      name  = "zoneIdFilters[0]"
      value = var.route53_zone_id
    }
  }

  depends_on = [kubernetes_service_account_v1.external_dns]
}
