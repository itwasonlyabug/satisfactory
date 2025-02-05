data "aws_iam_policy_document" "allow_ssm_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ssm" {
  name               = "SSMRole"
  assume_role_policy = data.aws_iam_policy_document.allow_ssm_access.json
}

resource "aws_iam_role_policy_attachment" "ec2attach" {
  role       = aws_iam_role.satisfactory_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ssm_parameter" "discord" {
  name  = "discord"
  type  = "String"
  value = var.discord_webhook_url
}
