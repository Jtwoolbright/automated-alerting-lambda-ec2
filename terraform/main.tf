# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-ec2-reboot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda - EC2 reboot and SNS publish permissions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-ec2-reboot-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RebootInstances"
        ]
        Resource = aws_instance.target_instance.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.reboot_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Create ZIP file of Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "ec2_reboot" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ec2-reboot-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      EC2_INSTANCE_ID = aws_instance.target_instance.id
      SNS_TOPIC_ARN   = aws_sns_topic.reboot_notifications.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# EC2 Instance
resource "aws_instance" "target_instance" {
  ami           = "ami-0532be01f26a3de55" 
  instance_type = "t2.micro"
  
  tags = {
    Name = "Lambda-Reboot-Target"
  }
}

# SNS Topic
resource "aws_sns_topic" "reboot_notifications" {
  name = "ec2-reboot-notifications"

  tags = {
    Name = "EC2 Reboot Notifications"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.reboot_notifications.arn
  protocol  = "email"
  endpoint  = "woolbright.josh.t@gmail.com" 
}