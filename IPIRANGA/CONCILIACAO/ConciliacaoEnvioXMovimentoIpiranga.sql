SELECT 
    CAST(c.DataEnvio AS date) AS DataTransmissao,
    MIN(c.DataMovimento) AS PrimeiraDataVenda,
    MAX(c.DataMovimento) AS UltimaDataVenda,
    COUNT(*) AS QtdConsolidacoes,
    SUM(CASE 
            WHEN CAST(c.DataEnvio AS date) > DATEADD(DAY, 1, c.DataMovimento) 
                THEN 1 
            ELSE 0 
        END) AS QtdComAtraso
FROM [Integracao.Ipiranga].PDV_ConciliacaoIpiranga c
WHERE c.IdEmpresa = 1
  AND c.CodigoComponente = 1331007
  AND c.DataMovimento BETWEEN '2026-06-01' AND '2026-06-21'
GROUP BY CAST(c.DataEnvio AS date)
ORDER BY DataTransmissao;
