-- =========================================================
-- Consultas analíticas do lakehouse BCB (Athena / workgroup "portfolio")
-- =========================================================

-- 1. Dólar: últimos 12 meses (camada gold)
SELECT mes,
       CAST(media  AS DECIMAL(10, 4)) AS dolar_medio,
       CAST(minimo AS DECIMAL(10, 4)) AS dolar_minimo,
       CAST(maximo AS DECIMAL(10, 4)) AS dolar_maximo,
       variacao_pct_mes
FROM lakehouse_bcb.gold_indicadores_mensais
WHERE serie = 'dolar'
ORDER BY mes DESC
LIMIT 12;

-- 2. Dólar x Selic anualizada, mês a mês
--    Selic SGS 11 é taxa diária (% a.d.); anualizada em 252 dias úteis
SELECT d.mes,
       CAST(d.media AS DECIMAL(10, 4)) AS dolar_medio,
       ROUND((POWER(1 + CAST(s.media AS DOUBLE) / 100, 252) - 1) * 100, 2) AS selic_anual_pct
FROM lakehouse_bcb.gold_indicadores_mensais d
JOIN lakehouse_bcb.gold_indicadores_mensais s
  ON d.mes = s.mes AND s.serie = 'selic'
WHERE d.serie = 'dolar'
ORDER BY d.mes;

-- 3. Meses com deflação (IPCA negativo)
SELECT mes,
        CAST(media AS DECIMAL(10, 2)) AS ipca_pct_mes
FROM lakehouse_bcb.gold_indicadores_mensais
WHERE serie = 'ipca' AND media < 0
ORDER BY mes;

-- 4. Partition pruning: compare o "Data scanned" das duas consultas
-- 4a. Sem filtro de partição: lê todas as séries
SELECT COUNT(*) AS linhas, SUM(valor) AS soma
FROM lakehouse_bcb.silver_series;

-- 4b. Com filtro de partição: lê só a pasta serie=dolar
SELECT COUNT(*) AS linhas, SUM(valor) AS soma
FROM lakehouse_bcb.silver_series
WHERE serie = 'dolar';