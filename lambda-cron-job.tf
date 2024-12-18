# Provider Configuration
provider "aws" {
  region = "us-east-1"  
}

# S3 Bucket for Terraform State and Lambda Code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-lambda-cron-bucket001"  # Replace with a globally unique bucket name
  force_destroy = true
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_bucket001_encryption" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lambda Function Code
resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_function.zip"
  source = "lambda_function.zip"  # You need to create this ZIP file with your Lambda code
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-cron-execution-role"

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

# IAM Policy for Lambda Execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda Function
resource "aws_lambda_function" "cron_lambda" {
  function_name = "my-cron-lambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambda_code.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"  # Adjust based on your Lambda function
  runtime       = "python3.9"      # Adjust based on your Lambda runtime

  # Optional configuration
  timeout     = 30
  memory_size = 128
}

# CloudWatch Events Rule (Cron Trigger)
resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  name                = "every-five-minutes"
  description         = "Fires every five minutes"
  schedule_expression = "rate(5 minutes)"
}

# Connect Lambda to CloudWatch Events
resource "aws_cloudwatch_event_target" "check_lambda_every_five_minutes" {
  rule      = aws_cloudwatch_event_rule.every_five_minutes.name
  target_id = "lambda"
  arn       = aws_lambda_function.cron_lambda.arn
}

# Permission for CloudWatch to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cron_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_five_minutes.arn
}

# Optional: Terraform State Backend Configuration
terraform {
  backend "s3" {
    bucket = "my-lambda-cron-bucket"  # Same as the S3 bucket created above
    key    = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
