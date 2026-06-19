DECLARE @IdNotaDevolucao BIGINT = 6519672;

WITH Vinculo AS (
    SELECT
        ref.IdNotaFiscal AS IdNotaDevolucao,
        ref.IdDocumentoFiscalReferenciado AS IdDocumentoOriginal
    FROM FAT_DocumentoFiscalReferenciado ref
    WHERE ref.IdNotaFiscal = @IdNotaDevolucao
)
SELECT
    CASE 
        WHEN df.Id = v.IdDocumentoOriginal THEN 'VENDA ORIGINAL'
        WHEN df.Id = v.IdNotaDevolucao THEN 'DEVOLUCAO'
    END AS Tipo,
    df.Id AS IdDocumentoFiscal,
    df.Numero,
    df.Fluxo,
    nf.TipoNotaGenerica,
    item.Id AS IdItemDocumentoFiscal,
    item.IdMercadoria,
    item.CodigoFiscalOperacaoCompleto,
    est.IdLocalEstoque AS IdTanque,
    est.Quantidade,
    CASE
        WHEN df.Fluxo = 0 THEN est.Quantidade
        WHEN df.Fluxo = 1 THEN est.Quantidade * -1
    END AS QuantidadeComSinal,
    est.Status,
    est.DataMovimentacao,
    est.HoraMovimentacao
FROM Vinculo v
INNER JOIN FAT_DocumentoFiscal df
    ON df.Id IN (v.IdDocumentoOriginal, v.IdNotaDevolucao)
INNER JOIN FAT_ItemDocumentoFiscal item
    ON item.IdDocumentoFiscal = df.Id
LEFT JOIN EST_EstoqueItemDocumentoFiscal est
    ON est.IdItemDocumentoFiscal = item.Id
LEFT JOIN FAT_NotaFiscal nf
    ON nf.Id = df.Id
WHERE item.IdMercadoria = 2
ORDER BY Tipo DESC, df.Id, est.IdLocalEstoque;
