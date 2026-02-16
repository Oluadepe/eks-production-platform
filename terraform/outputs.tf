output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}


output "effective_acm_certificate_arn" {
  description = "ACM certificate ARN used by the ALB ingress (either created by Terraform or provided)."
  value       = local.effective_acm_arn
}
