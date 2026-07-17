SELECT 
    c.Id,
    c.DataMovimento AS DataVenda,
    DATEADD(DAY, 1, c.DataMovimento) AS DataEsperadaTransmissaoD1,
    c.DataEnvio AS DataHoraTransmissaoReal,
    DATEDIFF(DAY, DATEADD(DAY, 1, c.DataMovimento), CAST(c.DataEnvio AS date)) AS DiasDeAtrasoAposD1,
    CASE 
        WHEN c.DataEnvio IS NULL 
            THEN 'Nao enviado'
        WHEN CAST(c.DataEnvio AS date) = DATEADD(DAY, 1, c.DataMovimento)
            THEN 'Transmitido no D-1 esperado'
        WHEN CAST(c.DataEnvio AS date) > DATEADD(DAY, 1, c.DataMovimento)
            THEN 'Transmitido apos D-1'
        ELSE 'Transmitido antes do D-1'
    END AS AnaliseD1,
    c.CodigoComponente,
    c.Enviado,
    c.DadosRetorno
FROM [Integracao.Ipiranga].PDV_ConciliacaoIpiranga c
WHERE c.IdEmpresa = 1
  AND c.DataMovimento IN (
      '2026-06-08',
      '2026-06-10',
      '2026-06-12',
      '2026-06-13',
      '2026-06-18'
  )
ORDER BY c.DataMovimento;
