variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project/name prefix"
  type        = string
  default     = "eks-prod"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.20.64.0/20", "10.20.80.0/20", "10.20.96.0/20"]
}

variable "node_instance_types" {
  description = "Node instance types"
  type        = list(string)
  default     = ["t3.large"]
}

variable "desired_nodes" {
  type        = number
  default     = 2
}
variable "min_nodes" {
  type        = number
  default     = 2
}
variable "max_nodes" {
  type        = number
  default     = 6
}

variable "enable_public_endpoint" {
  description = "Expose EKS API publicly (true) or only privately (false)"
  type        = bool
  default     = true
}

variable "admin_role_arns" {
  description = "IAM role ARNs to grant cluster-admin access via aws-auth (optional)"
  type        = list(string)
  default     = []
}


variable "domain_name" {
  description = "Base domain used for demo hostname (e.g., example.com). Used by ExternalDNS and optional ACM automation."
  type        = string
  default     = "example.com"
}

variable "demo_hostname" {
  description = "Fully-qualified domain name for the demo ingress (e.g., demo.example.com)."
  type        = string
  default     = "demo.example.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain_name. Required for ExternalDNS and ACM DNS validation automation."
  type        = string
  default     = ""
}

variable "create_acm_certificate" {
  description = "If true and route53_zone_id is set, Terraform will request/validate an ACM certificate for demo_hostname."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN to use for ALB HTTPS. If create_acm_certificate=true, this is ignored."
  type        = string
  default     = ""
}

variable "enable_external_dns" {
  description = "Install ExternalDNS (Route53) via Helm + IRSA."
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Install cert-manager via Helm. Includes a sample ClusterIssuer for Route53 DNS01."
  type        = bool
  default     = true
}
