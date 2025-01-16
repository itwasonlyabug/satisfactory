locals {
  apigateway = trimsuffix(trimprefix(aws_apigatewayv2_api.satisfactory.api_endpoint, "https://"), "/") 
}

data "cloudflare_zone" "satisfactory" {
  name = var.domain
}

resource "cloudflare_record" "satisfactory_A" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "@"
  value   = aws_eip.satisfactory_eip.public_ip
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "up_satisfactory_CNAME" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "up"
  value   = local.apigateway
  type    = "CNAME"
  ttl     = 120
}

resource "cloudflare_record" "satisfactory_CNAME" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "www"
  value   = var.domain
  type    = "CNAME"
  ttl     = 120
}

resource "cloudflare_record" "satisfactory_mail_TXT1" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "_dmarc"
  value   = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_record" "satisfactory_mail_TXT2" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "*._domainkey"
  value   = "v=DKIM1; p="
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_record" "satisfactory_mail_TXT3" {
  zone_id = data.cloudflare_zone.satisfactory.id
  name    = "@"
  value   = "v=spf1 -all"
  type    = "TXT"
  ttl     = 1
}

