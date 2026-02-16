# AWS Load Balancer Controller (ALB Ingress Controller)
# This enables Ingress resources with `kubernetes.io/ingress.class: alb` to provision AWS ALBs.
#
# It uses IRSA (IAM Roles for Service Accounts) so the controller gets AWS permissions securely.

locals {
  alb_controller_sa_name      = "aws-load-balancer-controller"
  alb_controller_namespace    = "kube-system"
  alb_controller_release_name = "aws-load-balancer-controller"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project}-AWSLoadBalancerControllerPolicy"
  description = "IAM policy for AWS Load Balancer Controller (managed by Terraform)"
  policy      = file("${path.module}/iam/aws-load-balancer-controller-policy.json")
}

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name_prefix = "${var.project}-alb-ctl-"

  role_policy_arns = {
    alb = aws_iam_policy.alb_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.alb_controller_namespace}:${local.alb_controller_sa_name}"]
    }
  }
}

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = local.alb_controller_sa_name
    namespace = local.alb_controller_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "alb_controller" {
  name       = local.alb_controller_release_name
  namespace  = local.alb_controller_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  # If you want to pin versions for stability, set this:
  # version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  # Use the pre-created service account with IRSA annotation
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = local.alb_controller_sa_name
  }

  # Recommended: explicit ingress class name "alb"
  set {
    name  = "ingressClass"
    value = "alb"
  }

  depends_on = [kubernetes_service_account_v1.alb_controller]
}
