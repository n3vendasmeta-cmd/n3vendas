DECLARE @DataInicio DATE = '2026-05-25';
DECLARE @DataTermino DATE = '2026-06-24';

WITH Dias AS
(
    SELECT @DataInicio AS DataMovimento
    UNION ALL
    SELECT DATEADD(DAY, 1, DataMovimento)
    FROM Dias
    WHERE DataMovimento < @DataTermino
),
Envio AS
(
    SELECT
        SUM(CONVERT(DECIMAL(18,5), F.Total)) AS TotalEnviado
    FROM Dias D
    OUTER APPLY [Integracao.Raizen].[FN_Venda_PegarDadosEnviarThoth](1, D.DataMovimento) F
),
Rel507 AS
(
    SELECT
        SUM(TotalVenda) AS TotalRelatorio507
    FROM dbo.FN_Relatorio0507VendaMercadoriaShellSelect('1', @DataInicio, @DataTermino, '', 1)
),
SemVinculo AS
(
    SELECT
        SUM(VIDF.ValorLiquidoTotalFinal) AS TotalSemVinculo
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
),
Cancelados AS
(
    SELECT
        SUM(VIDF.ValorLiquidoTotalFinal) AS TotalCancelado
    FROM [Integracao.Raizen].[VIEW_FAT_DocumentoFiscal_VendaThoth] VDF
    INNER JOIN [Integracao.Raizen].[VIEW_FAT_ItemDocumentoFiscal_VendaThoth] VIDF
        ON VDF.Id = VIDF.IdDocumentoFiscal
    WHERE VDF.IdEmpresa = 1
      AND CONVERT(DATE, VDF.DataMovimentacao) BETWEEN @DataInicio AND @DataTermino
      AND (VDF.Cancelado = 1 OR VIDF.Cancelado = 1)
)
SELECT
    Envio.TotalEnviado,
    Rel507.TotalRelatorio507,
    Envio.TotalEnviado - Rel507.TotalRelatorio507 AS Diferenca,
    SemVinculo.TotalSemVinculo,
    Cancelados.TotalCancelado,
    SemVinculo.TotalSemVinculo + Cancelados.TotalCancelado AS DiferencaExplicada
FROM Envio
CROSS JOIN Rel507
CROSS JOIN SemVinculo
CROSS JOIN Cancelados
OPTION (MAXRECURSION 0);
