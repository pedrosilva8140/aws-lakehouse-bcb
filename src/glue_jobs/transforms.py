from pyspark.sql import DataFrame
from pyspark.sql import functions as F

SERIES_VALIDAS = ["dolar", "selic", "ipca"]


def bronze_para_silver(df: DataFrame) -> DataFrame:
    """Converte tipos, remove inválidos e duplicatas, e cria a coluna de partição."""
    return (
        df.withColumn("data", F.to_date("data", "dd/MM/yyyy"))
        .withColumn("valor", F.col("valor").cast("decimal(18,6)"))
        .withColumn("ingested_at", F.col("ingested_at").cast("timestamp"))
        .dropna(subset=["data", "valor", "serie"])
        .dropDuplicates(["serie", "data"])
        .withColumn("ano", F.year("data"))
        .select("serie", "data", "valor", "ingested_at", "ano")
    )


def verificar_qualidade(df: DataFrame) -> None:
    """Lança erro se alguma regra de qualidade for violada."""
    erros = []
    if df.filter(~F.col("serie").isin(SERIES_VALIDAS)).count() > 0:
        erros.append("série desconhecida")
    if df.filter(F.col("valor") < 0).count() > 0:
        erros.append("valor negativo")
    dolar_fora = df.filter((F.col("serie") == "dolar") & ~F.col("valor").between(1, 20))
    if dolar_fora.count() > 0:
        erros.append("dólar fora da faixa 1-20")
    if df.groupBy("serie", "data").count().filter("count > 1").count() > 0:
        erros.append("data duplicada por série")
    if erros:
        raise ValueError("Qualidade de dados reprovada: " + "; ".join(erros))