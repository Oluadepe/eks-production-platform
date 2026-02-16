# Optional: map additional admin roles into aws-auth.
# NOTE: If you don't need this, you can remove this file.
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [
        # Managed Node Group role is auto-added by the module; kept here for clarity if you later manage aws-auth yourself.
      ],
      [
        for arn in var.admin_role_arns : {
          rolearn  = arn
          username = "admin"
          groups   = ["system:masters"]
        }
      ]
    ))
  }

  depends_on = [module.eks]
}
