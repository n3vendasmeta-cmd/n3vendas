/*
    Objetivo:
    Validar mercadorias pendentes de exportacao INFORLUB que podem gerar
    NullReferenceException no GerenciadorPDV.

    Erro relacionado:
    AdaptadorMercadoriaCargaExportacao.Adaptar(mercadoria, valorPreco)

    Possiveis causas:
    - Mercadoria sem preco em ValorPrecoCarga
    - Mercadoria sem UnidadeVenda
    - UnidadeVenda inexistente/orfa
    - Item de exportacao com mercadoria inexistente
*/

-- Resumo por tipo de problema
SELECT
    Diagnostico,
    COUNT(*) AS Quantidade
FROM
(
    SELECT
        CASE
            WHEN mer.Id IS NULL THEN 'Item de exportacao com mercadoria inexistente'
            WHEN mer.TipoMercadoria <> 4 AND mer.UnidadeVenda IS NULL THEN 'Mercadoria sem UnidadeVenda'
            WHEN mer.TipoMercadoria <> 4 AND und.Id IS NULL THEN 'UnidadeVenda inexistente/orfa'
            WHEN mer.TipoMercadoria <> 4 AND preco.Id IS NULL THEN 'Mercadoria sem preco em ValorPrecoCarga'
            ELSE 'OK'
        END AS Diagnostico
    FROM MercadoriaCargaExportacaoNaoEnviado exp WITH (NOLOCK)
    JOIN MercadoriaCargaExportacaoItensNaoEnviado item WITH (NOLOCK)
        ON item.MercadoriaCargaExportacaoNaoEnviado = exp.Id
    LEFT JOIN MercadoriaCarga mer WITH (NOLOCK)
        ON mer.Id = item.Mercadoria
    LEFT JOIN UnidadeVendaCarga und WITH (NOLOCK)
        ON und.Id = mer.UnidadeVenda
    LEFT JOIN ValorPrecoCarga preco WITH (NOLOCK)
        ON preco.Mercadoria = mer.Id
       AND (
            preco.Tipo = item.TipoPreco
            OR item.TipoPreco IS NULL
       )
    WHERE exp.TipoExportacao = 0 -- INFORLUB
) x
WHERE Diagnostico <> 'OK'
GROUP BY Diagnostico
ORDER BY Quantidade DESC;


-- Detalhamento das mercadorias com problema
SELECT
    exp.Id AS IdExportacao,
    item.Id AS IdItemExportacao,
    item.Mercadoria AS IdMercadoriaItem,
    mer.Id AS IdMercadoria,
    mer.Gtin,
    mer.Descricao,
    mer.DescricaoCompleta,
    mer.TipoMercadoria,
    mer.UnidadeVenda,
    und.UnidadeMedida,
    item.TipoPreco AS IdTipoPrecoItem,
    preco.Id AS IdValorPreco,
    preco.Tipo AS IdTipoPrecoPreco,
    preco.Valor,
    CASE
        WHEN mer.Id IS NULL THEN 'Item de exportacao com mercadoria inexistente'
        WHEN mer.TipoMercadoria <> 4 AND mer.UnidadeVenda IS NULL THEN 'Mercadoria sem UnidadeVenda'
        WHEN mer.TipoMercadoria <> 4 AND und.Id IS NULL THEN 'UnidadeVenda inexistente/orfa'
        WHEN mer.TipoMercadoria <> 4 AND preco.Id IS NULL THEN 'Mercadoria sem preco em ValorPrecoCarga'
        ELSE 'OK'
    END AS Diagnostico
FROM MercadoriaCargaExportacaoNaoEnviado exp WITH (NOLOCK)
JOIN MercadoriaCargaExportacaoItensNaoEnviado item WITH (NOLOCK)
    ON item.MercadoriaCargaExportacaoNaoEnviado = exp.Id
LEFT JOIN MercadoriaCarga mer WITH (NOLOCK)
    ON mer.Id = item.Mercadoria
LEFT JOIN UnidadeVendaCarga und WITH (NOLOCK)
    ON und.Id = mer.UnidadeVenda
LEFT JOIN ValorPrecoCarga preco WITH (NOLOCK)
    ON preco.Mercadoria = mer.Id
   AND (
        preco.Tipo = item.TipoPreco
        OR item.TipoPreco IS NULL
   )
WHERE exp.TipoExportacao = 0 -- INFORLUB
  AND (
        mer.Id IS NULL
        OR (mer.TipoMercadoria <> 4 AND mer.UnidadeVenda IS NULL)
        OR (mer.TipoMercadoria <> 4 AND und.Id IS NULL)
        OR (mer.TipoMercadoria <> 4 AND preco.Id IS NULL)
  )
ORDER BY mer.Id, item.Id;
