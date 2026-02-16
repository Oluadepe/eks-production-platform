# Terraform

Creates:
- VPC (public + private subnets, NAT)
- EKS cluster (managed node group)
- IRSA role for EBS CSI driver (IAM permissions)
- (Optional) aws-auth mapping for additional admin role ARNs

## Apply
```bash
terraform init
terraform apply
```

## Destroy
```bash
terraform destroy
```
