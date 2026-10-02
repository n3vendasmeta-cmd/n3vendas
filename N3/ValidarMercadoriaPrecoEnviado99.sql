DECLARE @idEmpresa BIGINT = 0; -- empresa

-- O que a 99 recebe
SELECT
    f.ProductCode,
    f.ProductDescription,
    f.Price AS PrecoEnviado,
    f.Status,
    f.IdCadMercadoriaNaoEnviada99Taxi
FROM [Integracao.99Taxi].[FN_ObterDadosDeEstoque99Taxi](@idEmpresa) f
ORDER BY f.ProductCode;

-- Valor + prioridade (marca qual vai)
SELECT
    f.ProductCode,
    f.ProductDescription,
    f.Price AS PrecoEnviado,
    p.Id AS IdPrecoMercadoria,
    p.Prioridade,
    p.PrecoCalculado,
    CASE WHEN p.Prioridade = px.PrioridadeMinima THEN 1 ELSE 0 END AS EhOEnviado
FROM [Integracao.99Taxi].[FN_ObterDadosDeEstoque99Taxi](@idEmpresa) f
INNER JOIN CAD_MercadoriaDadosEmpresa mde
    ON mde.IdMercadoria = f.ProductCode
   AND mde.IdEmpresa = @idEmpresa
LEFT JOIN CAD_PrecoMercadoria p
    ON p.IdMercadoriaDadosEmpresa = mde.Id
   AND p.IdEmpresa = @idEmpresa
OUTER APPLY (
    SELECT MIN(p2.Prioridade) AS PrioridadeMinima
    FROM CAD_PrecoMercadoria p2
    WHERE p2.IdMercadoriaDadosEmpresa = mde.Id
      AND p2.IdEmpresa = @idEmpresa
) px
ORDER BY f.ProductCode, p.Prioridade;
