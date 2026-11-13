import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME", "BUCKET"])
glue = GlueContext(SparkContext.getOrCreate())
spark = glue.spark_session
job = Job(glue)
job.init(args["JOB_NAME"], args)

glue.create_dynamic_frame.from_catalog(
    database="lakehouse_bcb", table_name="silver_series"
).toDF().createOrReplaceTempView("silver")

gold = spark.sql("""
    WITH dedup AS (
        SELECT serie, data, valor,
               ROW_NUMBER() OVER (PARTITION BY serie, data ORDER BY ingested_at DESC) AS rn
        FROM silver
    ),
    mensal AS (
        SELECT serie,
               CAST(date_trunc('month', data) AS DATE) AS mes,
               AVG(valor) AS media,
               MIN(valor) AS minimo,
               MAX(valor) AS maximo,
               COUNT(*)   AS dias_com_dado
        FROM dedup
        WHERE rn = 1
        GROUP BY serie, CAST(date_trunc('month', data) AS DATE)
    )
    SELECT *,
           ROUND(100 * (media / LAG(media) OVER (PARTITION BY serie ORDER BY mes) - 1), 2)
               AS variacao_pct_mes
    FROM mensal
""")

# A gold é pequena: recalculada inteira a cada execução
destino = f"s3://{args['BUCKET']}/gold/indicadores_mensais/"
glue.purge_s3_path(destino, {"retentionPeriod": 0})

sink = glue.getSink(
    connection_type="s3",
    path=destino,
    enableUpdateCatalog=True,
    updateBehavior="UPDATE_IN_DATABASE",
    partitionKeys=["serie"],
)
sink.setFormat("glueparquet")
sink.setCatalogInfo(catalogDatabase="lakehouse_bcb", catalogTableName="gold_indicadores_mensais")
sink.writeFrame(DynamicFrame.fromDF(gold, glue, "gold"))
print(f"Gold: {gold.count()} linhas gravadas")

job.commit()