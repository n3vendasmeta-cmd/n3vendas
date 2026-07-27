DECLARE @DataInicio DATE = '2026-05-25';
DECLARE @DataTermino DATE = '2026-06-24';

SELECT TOP 50
    VIDF.IdMercadoria,
    MER.Descricao,
    MER.CodigoBarra,
    SUM(VIDF.Quantidade) AS Quantidade,
    SUM(VIDF.ValorLiquidoTotalFinal) AS Total
FROM VIEW_FAT_DocumentoFiscalVenda VDF
INNER JOIN VIEW_FAT_ItemDocumentoFiscalVenda VIDF
    ON VDF.Id = VIDF.IdDocumentoFiscal
INNER JOIN CAD_Mercadoria MER
    ON MER.Id = VIDF.IdMercadoria
OUTER APPLY
(
    SELECT TOP 1
        V.IdProdutoMeta
    FROM [Integracao.Raizen].VinculoSelconMeta V WITH (NOLOCK)
    INNER JOIN [Integracao.Raizen].ProdutoSelect P WITH (NOLOCK)
        ON P.Id = V.IdProdutoSelect
    INNER JOIN [Integracao.Raizen].SecaoSelect S WITH (NOLOCK)
        ON S.nivel2 = P.nivel2
    WHERE V.IdProdutoMeta = MER.Id
    ORDER BY V.dtSinc DESC
) ProdSelect
WHERE VDF.Cancelado = 0
  AND VIDF.Cancelado = 0
  AND VDF.IdEmpresa = 1
  AND CONVERT(DATE, VDF.DataMovimentacao) BETWEEN @DataInicio AND @DataTermino
  AND MER.TipoMercadoria <> 1
  AND ProdSelect.IdProdutoMeta IS NULL
GROUP BY
    VIDF.IdMercadoria,
    MER.Descricao,
    MER.CodigoBarra
ORDER BY
    Total DESC;
