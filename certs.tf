resource "tls_private_key" "satisfactory" {
  algorithm = "RSA"
}

resource "tls_cert_request" "satisfactory" {
  private_key_pem = tls_private_key.satisfactory.private_key_pem

  subject {
    common_name  = "satisfactory"
    organization = "satisfactory"
  }
}

resource "cloudflare_origin_ca_certificate" "satisfactory" {
  csr                = tls_cert_request.satisfactory.cert_request_pem
  hostnames          = ["${var.domain}", "up.${var.domain}"]
  request_type       = "origin-rsa"
  requested_validity = 90
}