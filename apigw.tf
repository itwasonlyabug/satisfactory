resource "aws_acm_certificate" "cloudflare_origin" {
  private_key      = tls_private_key.satisfactory.private_key_pem
  certificate_body = cloudflare_origin_ca_certificate.satisfactory.certificate
}

resource "aws_apigatewayv2_domain_name" "satisfactory" {
  domain_name = "up.${var.domain}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.cloudflare_origin.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api" "satisfactory" {
  name          = "satisfactory-http-api"
  protocol_type = "HTTP"
  cors_configuration {
      allow_credentials = false
      allow_headers     = []
      allow_methods     = [
          "GET",
      ]
      allow_origins     = [
          "*",
      ]
      expose_headers    = []
      max_age           = 0
  }
}

resource "aws_apigatewayv2_stage" "satisfactory" {
  api_id = aws_apigatewayv2_api.satisfactory.id
  name   = "$default"
  auto_deploy = "true"
}

resource "aws_apigatewayv2_integration" "satisfactory" {
  api_id           = aws_apigatewayv2_api.satisfactory.id
  integration_type = "AWS_PROXY"

  connection_type           = "INTERNET"
  description               = "Start Satisfactory"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.start_satisfactory.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
  payload_format_version    = "2.0"
}

resource "aws_apigatewayv2_api_mapping" "satisfactory" {
  api_id      = aws_apigatewayv2_api.satisfactory.id
  domain_name = aws_apigatewayv2_domain_name.satisfactory.id
  stage       = aws_apigatewayv2_stage.satisfactory.id
}

resource "aws_apigatewayv2_route" "satisfactory" {
  api_id    = aws_apigatewayv2_api.satisfactory.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.satisfactory.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_satisfactory.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.satisfactory.execution_arn}/*/*/*"
}
