data "aws_iam_policy_document" "assume_lambda_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "lambda.amazonaws.com",
      ]
    }

  }
}

data "aws_iam_policy_document" "ec2_start_permissions" {
  statement {
    sid = "1"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test = "StringEquals"
      variable = "aws:ResourceTag/Name"
      values = ["Satisfactory"]
    }
  }
  statement {
    sid = "2"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
    ]
    resources = ["*"]
  }
  statement {
    sid = "3"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::satisfactoryserversaves",
      "arn:aws:s3:::satisfactoryserversaves/*"
    ]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = "StartSatisfactory"
  path   = "/"
  policy = data.aws_iam_policy_document.ec2_start_permissions.json
}

resource "aws_iam_role" "satisfactory_lambda" {
  name                = "Satisfactory"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_role_policy.json
}

resource "aws_iam_role_policy_attachment" "satisfactory_lambda" {
  role       = aws_iam_role.satisfactory_lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "aws_iam_instance_profile" "satisfactory" {
  name = "satisfactory"
  role = aws_iam_role.satisfactory_lambda.name
}
