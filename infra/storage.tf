# Bucket do data lake: nome único usando o ID da conta
resource "aws_s3_bucket" "lake" {
  bucket        = "lakehouse-bcb-${data.aws_caller_identity.eu.account_id}"
  force_destroy = true # permite apagar o bucket mesmo com dados dentro
}

# Bloqueia qualquer acesso público ao bucket
resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Banco de dados no catálogo do Glue (onde as tabelas serão registradas)
resource "aws_glue_catalog_database" "bcb" {
  name = "lakehouse_bcb"
}

# Workgroup do Athena com trava de custo
resource "aws_athena_workgroup" "portfolio" {
  name          = "portfolio"
  force_destroy = true
  configuration {
    bytes_scanned_cutoff_per_query = 1073741824 # máximo 1 GB lido por consulta
    result_configuration {
      output_location = "s3://${aws_s3_bucket.lake.bucket}/athena-results/"
    }
  }
}

# Mostra o nome do bucket no final do apply
output "bucket" {
  value = aws_s3_bucket.lake.bucket
}