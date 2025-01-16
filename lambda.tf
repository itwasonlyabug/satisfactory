data "template_file" "lambda" {
  template = "${file("./lambda.py")}"
  vars = {
    aws_instance = aws_instance.satisfactory_server.id
    aws_region = var.aws_region
  }
}

data "archive_file" "lambda" {
  type = "zip"
  source { 
    content = data.template_file.lambda.rendered
    filename = "lambda.py"
  }
  output_path = "${path.module}/satisfactory.zip"
}

resource "aws_lambda_function" "start_satisfactory" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "satisfactory.zip"
  function_name = "StartSatisfactory"
  role          = aws_iam_role.satisfactory_lambda.arn
  handler       = "lambda.lambda_handler" 

  source_code_hash = base64sha256(data.template_file.lambda.rendered)

  runtime = "python3.10"

  environment {
    variables = {
      DISCORD_WEBHOOK = var.discord_webhook_url
    }
  }

}

resource "aws_lambda_function_url" "call_lambda" {
  function_name      = aws_lambda_function.start_satisfactory.function_name
  authorization_type = "AWS_IAM"
}

output "lambda" {
  value = aws_lambda_function_url.call_lambda.function_url
}
