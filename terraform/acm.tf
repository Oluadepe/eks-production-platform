# Optional ACM certificate automation.
# If you already have a certificate, set var.acm_certificate_arn and keep var.create_acm_certificate=false.
#
# If you want Terraform to request and validate the certificate automatically:
# - set var.create_acm_certificate=true
# - set var.route53_zone_id to your hosted zone ID
#
# NOTE: ACM cert for ALB must be in the SAME region as the ALB/EKS.

resource "aws_acm_certificate" "demo" {
  count             = var.create_acm_certificate && var.route53_zone_id != "" ? 1 : 0
  domain_name       = var.demo_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = var.project
  }
}

resource "aws_route53_record" "demo_validation" {
  count   = var.create_acm_certificate && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = aws_acm_certificate.demo[0].domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.demo[0].domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.demo[0].domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "demo" {
  count                  = var.create_acm_certificate && var.route53_zone_id != "" ? 1 : 0
  certificate_arn        = aws_acm_certificate.demo[0].arn
  validation_record_fqdns = [aws_route53_record.demo_validation[0].fqdn]
}

locals {
  effective_acm_arn = var.create_acm_certificate && var.route53_zone_id != "" ? aws_acm_certificate_validation.demo[0].certificate_arn : var.acm_certificate_arn
}
