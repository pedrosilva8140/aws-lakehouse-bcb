from datetime import date
from decimal import Decimal

import pytest

from src.glue_jobs.transforms import bronze_para_silver, verificar_qualidade

COLUNAS = ["data", "valor", "serie", "ingested_at"]
AGORA = "2026-11-13T02:21:32+00:00"


def bronze(spark, linhas):
    """Cria um DataFrame no formato da camada bronze."""
    return spark.createDataFrame(linhas, COLUNAS)


def test_converte_data_e_valor(spark):
    linha = bronze_para_silver(bronze(spark, [("03/11/2025", "5.3505", "dolar", AGORA)])).first()
    assert linha.data == date(2025, 11, 3)
    assert linha.valor == Decimal("5.3505")
    assert linha.ano == 2025


def test_remove_duplicatas(spark):
    repetida = ("03/11/2025", "5.3505", "dolar", AGORA)
    assert bronze_para_silver(bronze(spark, [repetida, repetida])).count() == 1


def test_descarta_data_invalida(spark):
    df = bronze_para_silver(bronze(spark, [("data-ruim", "5.30", "dolar", AGORA)]))
    assert df.count() == 0


def test_aprova_dados_validos(spark):
    df = bronze_para_silver(bronze(spark, [
        ("03/11/2025", "5.35", "dolar", AGORA),
        ("03/11/2025", "15.00", "selic", AGORA),
    ]))
    verificar_qualidade(df)  # não deve lançar erro


def test_reprova_dolar_fora_da_faixa(spark):
    df = bronze_para_silver(bronze(spark, [("03/11/2025", "510", "dolar", AGORA)]))
    with pytest.raises(ValueError, match="faixa"):
        verificar_qualidade(df)

def test_aceita_ipca_negativo_deflacao(spark):
    df = bronze_para_silver(bronze(spark, [("01/08/2025", "-0.11", "ipca", AGORA)]))
    verificar_qualidade(df)  # deflação é válida: não deve lançar erro


def test_reprova_selic_negativa(spark):
    df = bronze_para_silver(bronze(spark, [("03/11/2025", "-0.05", "selic", AGORA)]))
    with pytest.raises(ValueError, match="negativo"):
        verificar_qualidade(df)      