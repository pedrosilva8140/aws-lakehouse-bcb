# Sobe os scripts para o bucket (o etag faz reenviar quando o arquivo muda)
locals {
  scripts = ["transforms.py", "bronze_to_silver.py", "silver_to_gold.py"]
}

resource "aws_s3_object" "scripts" {
  for_each = toset(local.scripts)
  bucket   = aws_s3_bucket.lake.id
  key      = "scripts/${each.value}"
  source   = "${path.module}/../src/glue_jobs/${each.value}"
  etag     = filemd5("${path.module}/../src/glue_jobs/${each.value}")
}

# Identidade dos jobs do Glue
resource "aws_iam_role" "glue" {
  name = "bcb-glue"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Permissões padrão do Glue (catálogo, logs, métricas)
resource "aws_iam_role_policy_attachment" "glue_servico" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Acesso ao bucket do lake
resource "aws_iam_role_policy" "glue_s3" {
  role = aws_iam_role.glue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.lake.arn, "${aws_s3_bucket.lake.arn}/*"]
    }]
  })
}

resource "aws_glue_job" "bronze_to_silver" {
  name              = "bcb-bronze-to-silver"
  role_arn          = aws_iam_role.glue.arn
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2 # mínimo; o padrão (10) custaria 5x mais
  timeout           = 15

  command {
    script_location = "s3://${aws_s3_bucket.lake.bucket}/scripts/bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--BUCKET"                           = aws_s3_bucket.lake.bucket
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--extra-py-files"                   = "s3://${aws_s3_bucket.lake.bucket}/scripts/transforms.py"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}

resource "aws_glue_job" "silver_to_gold" {
  name              = "bcb-silver-to-gold"
  role_arn          = aws_iam_role.glue.arn
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 15

  command {
    script_location = "s3://${aws_s3_bucket.lake.bucket}/scripts/silver_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--BUCKET"                           = aws_s3_bucket.lake.bucket
    "--enable-continuous-cloudwatch-log" = "true"
  }
}