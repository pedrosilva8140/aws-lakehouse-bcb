# Empacota o handler.py em um .zip (gerado em infra/build, ignorado pelo Git)
data "archive_file" "ingestao" {
  type        = "zip"
  source_file = "${path.module}/../src/ingestion/handler.py"
  output_path = "${path.module}/build/ingestao.zip"
}

# Identidade da Lambda
resource "aws_iam_role" "lambda" {
  name = "bcb-ingestao-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Permissão para escrever logs no CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissão mínima: só gravar na camada bronze
resource "aws_iam_role_policy" "lambda_s3" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.lake.arn}/bronze/*"
    }]
  })
}

# A função
resource "aws_lambda_function" "ingestao" {
  function_name    = "bcb-ingestao"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.ingestao.output_path
  source_code_hash = data.archive_file.ingestao.output_base64sha256
  timeout          = 60
  environment {
    variables = { BUCKET = aws_s3_bucket.lake.bucket }
  }
}

# Agendamento diário às 12:00 UTC (09:00 em Brasília), desligado por padrão
resource "aws_cloudwatch_event_rule" "diario" {
  name                = "bcb-ingestao-diaria"
  schedule_expression = "cron(0 12 * * ? *)"
  state               = var.agendar ? "ENABLED" : "DISABLED"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.diario.name
  arn  = aws_lambda_function.ingestao.arn
}

# Autoriza o EventBridge a chamar a Lambda
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "PermitirEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestao.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.diario.arn
}