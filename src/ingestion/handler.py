import json
import os
import urllib.error
import urllib.request
from datetime import UTC, date, datetime, timedelta

import boto3

# Séries do Banco Central: nome -> código SGS
SERIES = {"dolar": 1, "selic": 11, "ipca": 433}
API = (
    "https://api.bcb.gov.br/dados/serie/bcdata.sgs.{cod}/dados"
    "?formato=json&dataInicial={ini}&dataFinal={fim}"
)

s3 = boto3.client("s3")


def buscar_serie(cod: int, ini: date, fim: date) -> list[dict]:
    """Chama a API do BCB e devolve a lista de registros do período."""
    url = API.format(cod=cod, ini=ini.strftime("%d/%m/%Y"), fim=fim.strftime("%d/%m/%Y"))
    req = urllib.request.Request(url, headers={"User-Agent": "portfolio-de/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:  # sem dados no período (fim de semana, feriado)
            return []
        raise


def montar_linhas(registros: list[dict], serie: str, agora: str) -> str:
    """Converte para JSON Lines, acrescentando a série e o horário de ingestão."""
    return "\n".join(
        json.dumps({**r, "serie": serie, "ingested_at": agora}) for r in registros
    )


def handler(event, context):
    bucket = os.environ["BUCKET"]
    # Sem datas no evento: busca o dia de ontem
    fim = date.fromisoformat(event["data_fim"]) if "data_fim" in event else date.today() - timedelta(days=1)
    ini = date.fromisoformat(event["data_inicio"]) if "data_inicio" in event else fim
    agora = datetime.now(UTC).isoformat()

    total = 0
    for serie, cod in SERIES.items():
        registros = buscar_serie(cod, ini, fim)
        if not registros:
            continue
        # Chave determinística: reprocessar o mesmo período sobrescreve (idempotente)
        key = f"bronze/bcb/serie={serie}/inicio={ini}/fim={fim}/dados.jsonl"
        s3.put_object(Bucket=bucket, Key=key, Body=montar_linhas(registros, serie, agora).encode())
        total += len(registros)

    return {"registros": total, "inicio": str(ini), "fim": str(fim)}