import os
import sys

import pytest

# Windows: o Spark deve usar o Python do .venv nos processos de trabalho
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

from pyspark.sql import SparkSession


@pytest.fixture(scope="session")
def spark():
    """Uma sessão Spark local, compartilhada por todos os testes."""
    sessao = (
        SparkSession.builder.master("local[1]")
        .appName("testes")
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield sessao
    sessao.stop()