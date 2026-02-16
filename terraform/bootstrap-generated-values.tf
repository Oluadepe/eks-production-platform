# v1.2.2: Zero-manual-edit bootstrap for Helm values.
# After `terraform apply`, this writes a ready-to-use values file at:
#   generated/demo-web.values.yaml
#
# You can then deploy with:
#   helm upgrade --install demo-web ./helm/demo-web -f generated/demo-web.values.yaml

locals {
  tls_enabled_bool = local.effective_acm_arn != "" ? true : false
  tls_enabled_str  = local.tls_enabled_bool ? "true" : "false"
  acm_arn_effective = local.effective_acm_arn != "" ? local.effective_acm_arn : ""
}

resource "local_file" "demo_web_values" {
  filename = "${path.root}/../generated/demo-web.values.yaml"

  content = templatefile("${path.module}/templates/demo-web-values.yaml.tftpl", {
    hostname    = var.demo_hostname
    tls_enabled = local.tls_enabled_str
    acm_arn     = local.acm_arn_effective
  })
}
