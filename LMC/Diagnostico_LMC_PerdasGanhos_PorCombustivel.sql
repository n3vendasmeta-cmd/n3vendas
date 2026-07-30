DECLARE @IdEmpresa BIGINT = 32653;
DECLARE @IdCombustivel BIGINT = 5046;
DECLARE @Data DATE = '2025-05-09';

IF OBJECT_ID('tempdb..#NotasLMC') IS NOT NULL
    DROP TABLE #NotasLMC;

CREATE TABLE #NotasLMC (
    IdItemDocumentoFiscal BIGINT NULL,
    IdNotaFiscal BIGINT NULL,
    NumeroNota BIGINT NULL,
    DataMovimentacao DATETIME NULL,
    Quantidade DECIMAL(19,5) NULL,
    NumeroTanque INT NULL,
    IdMercadoria BIGINT NULL,
    Fluxo INT NULL,
    IdEstoqueItemDocumentoFiscal BIGINT NULL,
    IdLocalEstoque BIGINT NULL,
    UF INT NULL,
    IE VARCHAR(50) NULL,
    Modelo VARCHAR(20) NULL,
    Serie VARCHAR(20) NULL,
    CodigoFiscalOperacao VARCHAR(20) NULL,
    CNPJ VARCHAR(20) NULL,
    IdFornecedor BIGINT NULL,
    NomeFornecedor VARCHAR(255) NULL,
    DataEmissao DATETIME NULL,
    TipoNotaGenerica INT NULL,
    IdBico BIGINT NULL
);

INSERT INTO #NotasLMC
EXEC PC_ObterEntradasDeNotaDoCombustivelPeloPeriodo
    @IdEmpresa,
    @IdCombustivel,
    @Data,
    @Data;

;WITH SaldoTanque AS (
    SELECT
        DataMovimentacao,
        IdTanque,
        NumeroTanque,
        SaldoTanque
    FROM FN_EST_PegarSaldoMercadoriaPorIdComDadosDoTanqueLMC_PorPeriodo(
        CONVERT(VARCHAR(20), @IdCombustivel),
        @Data,
        @Data,
        @IdEmpresa
    )
),
Abertura AS (
    SELECT
        SUM(SaldoTanque) AS EstoqueAbertura
    FROM SaldoTanque
    WHERE DataMovimentacao = DATEADD(DAY, -1, @Data)
),
Fechamento AS (
    SELECT
        SUM(SaldoTanque) AS EstoqueFechamento
    FROM SaldoTanque
    WHERE DataMovimentacao = @Data
),
Vendas AS (
    SELECT
        SUM(VendaCaixa) AS TotalVenda
    FROM FN_PST_GetAbastecimentos(
        @Data,
        @Data,
        @IdEmpresa,
        @IdCombustivel,
        0
    )
),
Notas AS (
    SELECT
        SUM(CASE WHEN Fluxo = 0 THEN Quantidade ELSE 0 END) AS TotalEntradaNota,
        SUM(CASE WHEN Fluxo = 1 THEN Quantidade ELSE 0 END) AS TotalSaidaNota
    FROM #NotasLMC
)
SELECT
    CAST(a.EstoqueAbertura AS DECIMAL(19,3)) AS EstoqueAbertura,
    CAST(n.TotalEntradaNota AS DECIMAL(19,3)) AS TotalEntradaNota,
    CAST(ISNULL(n.TotalSaidaNota, 0) AS DECIMAL(19,3)) AS TotalSaidaNota,
    CAST(v.TotalVenda AS DECIMAL(19,3)) AS TotalVenda,
    CAST(f.EstoqueFechamento AS DECIMAL(19,3)) AS EstoqueFechamento,

    CAST(
        a.EstoqueAbertura
        + ISNULL(n.TotalEntradaNota, 0)
        - ISNULL(n.TotalSaidaNota, 0)
        - ISNULL(v.TotalVenda, 0)
        AS DECIMAL(19,3)
    ) AS EstoqueEscrituralCalculado,

    CAST(
        f.EstoqueFechamento
        - (
            a.EstoqueAbertura
            + ISNULL(n.TotalEntradaNota, 0)
            - ISNULL(n.TotalSaidaNota, 0)
            - ISNULL(v.TotalVenda, 0)
        )
        AS DECIMAL(19,3)
    ) AS PerdaGanhoCalculado
FROM Abertura a
CROSS JOIN Fechamento f
CROSS JOIN Vendas v
CROSS JOIN Notas n;

SELECT
    'Notas consideradas no LMC' AS Origem,
    NumeroNota,
    IdNotaFiscal,
    IdItemDocumentoFiscal,
    DataMovimentacao,
    Fluxo,
    CASE Fluxo
        WHEN 0 THEN 'Entrada'
        WHEN 1 THEN 'Saida'
    END AS TipoFluxo,
    Quantidade,
    IdEstoqueItemDocumentoFiscal,
    NumeroTanque
FROM #NotasLMC
ORDER BY DataMovimentacao, NumeroNota;

SELECT
    'Vendas consideradas no LMC' AS Origem,
    IdTanque,
    Tanque,
    Bico,
    CAST(SUM(VendaCaixa) AS DECIMAL(19,3)) AS VendaCaixa,
    CAST(SUM(Afericao) AS DECIMAL(19,3)) AS Afericao,
    COUNT(*) AS QtdRegistros
FROM FN_PST_GetAbastecimentos(
    @Data,
    @Data,
    @IdEmpresa,
    @IdCombustivel,
    0
)
GROUP BY
    IdTanque,
    Tanque,
    Bico
ORDER BY
    Tanque,
    Bico;

SELECT
    'Saldos considerados no LMC' AS Origem,
    DataMovimentacao,
    IdTanque,
    NumeroTanque,
    SaldoTanque
FROM FN_EST_PegarSaldoMercadoriaPorIdComDadosDoTanqueLMC_PorPeriodo(
    CONVERT(VARCHAR(20), @IdCombustivel),
    @Data,
    @Data,
    @IdEmpresa
)
ORDER BY DataMovimentacao, NumeroTanque;

SELECT
    'Variação temperatura/regua' AS Origem,
    IdDocumentoFiscal,
    NumeroNota,
    IdItemDocumentoFiscal,
    DataMovimentacao,
    Fluxo,
    CASE Fluxo
        WHEN 0 THEN 'Entrada'
        WHEN 1 THEN 'Saida'
    END AS TipoFluxo,
    Quantidade,
    NumeroTanque,
    IdTanque
FROM FN_PST_PegarAjustesDeEstoqueDeVariacaoDeTemperaturaPorTanque(
    @IdEmpresa,
    CONVERT(VARCHAR(20), @IdCombustivel),
    @Data,
    @Data
)
ORDER BY DataMovimentacao;
