/*
Diagnostico de abastecimentos que nao aparecem no LMC.

Como usar:
1. Execute no banco Global do cliente.
2. Preencha pelo menos um filtro:
   - @IdsAbastecimento: lista separada por virgula, ex: '4516611,4516612'
   - @IdDocumentoFiscal: id do FAT_DocumentoFiscal
   - @NumeroDocumento: numero do documento fiscal
   - @DataInicio/@DataTermino + @IdEmpresa
3. Confira o result set "Diagnostico": a coluna MotivoProvavelExclusao indica o filtro que removeu o registro.
*/

SET NOCOUNT ON;

DECLARE @IdsAbastecimento VARCHAR(MAX) = ''; -- Ex: '4516611,4516612'
DECLARE @IdDocumentoFiscal BIGINT = NULL;    -- Ex: 3663160
DECLARE @NumeroDocumento BIGINT = NULL;      -- Ex: 109445
DECLARE @IdEmpresa BIGINT = NULL;            -- Ex: 1
DECLARE @IdCombustivel BIGINT = 0;           -- 0 = todos
DECLARE @DataInicio DATE = NULL;             -- Ex: '2026-07-23'
DECLARE @DataTermino DATE = NULL;            -- Ex: '2026-07-23'

IF OBJECT_ID('tempdb..#FiltroAbastecimento') IS NOT NULL DROP TABLE #FiltroAbastecimento;
IF OBJECT_ID('tempdb..#BaseLMC') IS NOT NULL DROP TABLE #BaseLMC;

CREATE TABLE #FiltroAbastecimento
(
    IdAbastecimento BIGINT NOT NULL PRIMARY KEY
);

IF COALESCE(LTRIM(RTRIM(@IdsAbastecimento)), '') <> ''
BEGIN
    INSERT INTO #FiltroAbastecimento (IdAbastecimento)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM([value])) AS BIGINT)
    FROM STRING_SPLIT(@IdsAbastecimento, ',')
    WHERE TRY_CAST(LTRIM(RTRIM([value])) AS BIGINT) IS NOT NULL;
END;

INSERT INTO #FiltroAbastecimento (IdAbastecimento)
SELECT DISTINCT ab.Id
FROM dbo.PDV_Abastecimento ab WITH (NOLOCK)
LEFT JOIN dbo.FAT_ItemDocumentoFiscal item WITH (NOLOCK)
    ON item.IdItemCupom = ab.IdItemDocumentoFiscal
LEFT JOIN dbo.FAT_DocumentoFiscal doc WITH (NOLOCK)
    ON doc.Id = item.IdDocumentoFiscal
WHERE NOT EXISTS
(
    SELECT 1
    FROM #FiltroAbastecimento f
    WHERE f.IdAbastecimento = ab.Id
)
AND
(
    (@IdDocumentoFiscal IS NOT NULL AND doc.Id = @IdDocumentoFiscal)
    OR (@NumeroDocumento IS NOT NULL AND doc.Numero = @NumeroDocumento)
    OR
    (
        @DataInicio IS NOT NULL
        AND @DataTermino IS NOT NULL
        AND (@IdEmpresa IS NULL OR doc.IdEmpresa = @IdEmpresa)
        AND (@IdCombustivel = 0 OR ab.IdentificadorCombustivel = @IdCombustivel)
        AND ab.DiaHoraAbastecimento >= @DataInicio
        AND ab.DiaHoraAbastecimento < DATEADD(DAY, 1, @DataTermino)
    )
);

SELECT
    ab.Id AS IdAbastecimento,
    ab.IdItemDocumentoFiscal,
    ab.DiaHoraAbastecimento,
    ab.IdentificadorCombustivel,
    ab.Hdab,
    item.Id AS IdItemFat,
    item.IdItemCupom,
    item.IdDocumentoFiscal,
    item.IdMercadoria,
    item.Cancelado AS ItemCancelado,
    item.CodigoFiscalOperacao,
    item.TipoNotaFiscal,
    doc.IdEmpresa,
    doc.Cancelado AS DocumentoCancelado,
    doc.[Status],
    doc.TipoDocumento,
    doc.Numero,
    nota.Id AS IdNotaFiscal,
    nota.TipoNotaGenerica
INTO #BaseLMC
FROM #FiltroAbastecimento filtro
INNER JOIN dbo.PDV_Abastecimento ab WITH (NOLOCK)
    ON ab.Id = filtro.IdAbastecimento
LEFT JOIN dbo.FAT_ItemDocumentoFiscal item WITH (NOLOCK)
    ON item.IdItemCupom = ab.IdItemDocumentoFiscal
LEFT JOIN dbo.FAT_DocumentoFiscal doc WITH (NOLOCK)
    ON doc.Id = item.IdDocumentoFiscal
LEFT JOIN dbo.FAT_NotaFiscal nota WITH (NOLOCK)
    ON nota.Id = doc.Id;

PRINT '1) Base encontrada pelos filtros';
SELECT *
