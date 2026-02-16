module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.20.0"

  cluster_name    = "${var.project}-cluster"
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = var.enable_public_endpoint
  cluster_endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      name            = "${var.project}-mng"
      instance_types  = var.node_instance_types
      desired_size    = var.desired_nodes
      min_size        = var.min_nodes
      max_size        = var.max_nodes
      capacity_type   = "ON_DEMAND"
      ami_type        = "AL2_x86_64"
      subnet_ids      = module.vpc.private_subnets

      labels = {
        "workload" = "general"
      }
    }
  }

  # Minimal baseline addons; you can expand as needed
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = {
    Project = var.project
  }
}

# Kubernetes provider uses the EKS cluster outputs
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}


# Helm provider uses the same auth as kubectl for in-cluster installs (controllers, monitoring, etc.)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
