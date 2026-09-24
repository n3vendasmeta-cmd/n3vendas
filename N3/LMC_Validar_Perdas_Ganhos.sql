-- Motivo do perdas e ganhos (LMC)
-- 1) resumo do dia  2) documentos que geraram a diferença

DECLARE @idEmpresa     BIGINT = 31769;
DECLARE @data          DATE   = '20231025';
DECLARE @idCombustivel BIGINT = 3053;     -- ETANOL; NULL = todos

;WITH Mov AS
(
    SELECT
        e.IdEmpresa,
        e.IdMercadoria,
        e.IdLocalEstoque,
        CONVERT(DATE, e.DataMovimentacao) AS Data,
        e.DocumentoOrigem,
        e.Fluxo,
        e.Quantidade,
        df.DataMovimentacao AS DataDocumento,
        CASE
            WHEN e.DocumentoOrigem LIKE 'AJ%' THEN 'AJUSTE_REGUA'
            WHEN df.Id IS NOT NULL
             AND CONVERT(DATE, df.DataMovimentacao) <> CONVERT(DATE, e.DataMovimentacao)
            THEN 'NOTA_DATA_DIFERENTE'
            WHEN df.Id IS NOT NULL THEN 'NOTA_MESMO_DIA'
            ELSE 'OUTRO'
        END AS Tipo
    FROM EST_EstoqueFisicoAnalitico e
    OUTER APPLY
    (
        SELECT TOP 1 df2.Id, df2.DataMovimentacao
        FROM FAT_DocumentoFiscal df2
        WHERE df2.IdEmpresa = e.IdEmpresa
          AND df2.Numero = e.DocumentoOrigem
        ORDER BY ABS(DATEDIFF(DAY, df2.DataMovimentacao, e.DataMovimentacao)), df2.Id
    ) df
    WHERE e.IdEmpresa = @idEmpresa
      AND CONVERT(DATE, e.DataMovimentacao) = @data
      AND (@idCombustivel IS NULL OR e.IdMercadoria = @idCombustivel)
),
Dia AS
(
    SELECT
        IdEmpresa,
        IdMercadoria,
        IdLocalEstoque,
        Data,
        SUM(CASE WHEN Fluxo = 0 AND Tipo = 'NOTA_DATA_DIFERENTE' THEN Quantidade ELSE 0 END) AS NotaDataErradaEntrada,
        SUM(CASE WHEN Fluxo = 1 AND Tipo = 'NOTA_DATA_DIFERENTE' THEN Quantidade ELSE 0 END) AS NotaDataErradaSaida,
        SUM(CASE WHEN Fluxo = 0 AND Tipo = 'AJUSTE_REGUA' THEN Quantidade ELSE 0 END) AS AjusteEntrada,
        SUM(CASE WHEN Fluxo = 1 AND Tipo = 'AJUSTE_REGUA' THEN Quantidade ELSE 0 END) AS AjusteSaida,
        SUM(CASE WHEN Fluxo = 0 AND Tipo = 'NOTA_MESMO_DIA' THEN Quantidade ELSE 0 END) AS NotaLivroEntrada,
        SUM(CASE WHEN Fluxo = 1 AND Tipo <> 'AJUSTE_REGUA' THEN Quantidade ELSE 0 END) AS SaidaSemAjuste
    FROM Mov
    GROUP BY IdEmpresa, IdMercadoria, IdLocalEstoque, Data
)
SELECT
    'RESUMO' AS Parte,
    d.Data,
    t.Numero AS Tanque,
    m.Id AS IdCombustivel,
    m.Descricao AS Combustivel,
    CAST(NULL AS VARCHAR(30)) AS Documento,
    CAST(NULL AS VARCHAR(30)) AS Tipo,
    CAST(NULL AS DATE) AS DataDocumento,
    dbo.FN_EST_PegarSaldoMercadoriaPorDataLocal(d.IdEmpresa, d.IdMercadoria, DATEADD(DAY, -1, d.Data), d.IdLocalEstoque) AS Abertura,
    dbo.FN_EST_PegarSaldoMercadoriaPorDataLocal(d.IdEmpresa, d.IdMercadoria, d.Data, d.IdLocalEstoque) AS Fechamento,
    dbo.FN_EST_PegarSaldoMercadoriaPorDataLocal(d.IdEmpresa, d.IdMercadoria, DATEADD(DAY, -1, d.Data), d.IdLocalEstoque)
      + d.NotaLivroEntrada
      - d.SaidaSemAjuste AS Escritural,
    dbo.FN_EST_PegarSaldoMercadoriaPorDataLocal(d.IdEmpresa, d.IdMercadoria, d.Data, d.IdLocalEstoque)
      - (
            dbo.FN_EST_PegarSaldoMercadoriaPorDataLocal(d.IdEmpresa, d.IdMercadoria, DATEADD(DAY, -1, d.Data), d.IdLocalEstoque)
          + d.NotaLivroEntrada
          - d.SaidaSemAjuste
        ) AS PerdasGanhos,
    d.NotaDataErradaEntrada - d.NotaDataErradaSaida AS EfeitoNotaDataErrada,
    d.AjusteEntrada - d.AjusteSaida AS EfeitoAjusteRegua,
    CASE
        WHEN (d.NotaDataErradaEntrada + d.NotaDataErradaSaida) > 0
         AND (d.AjusteEntrada + d.AjusteSaida) > 0
        THEN 'Nota com data diferente no estoque + ajuste de régua (AJ)'
        WHEN (d.NotaDataErradaEntrada + d.NotaDataErradaSaida) > 0
        THEN 'Nota no estoque em data diferente do documento'
        WHEN (d.AjusteEntrada + d.AjusteSaida) > 0
        THEN 'Ajuste de régua (AJ) — o livro não usa na conta'
        ELSE 'Outro movimento no tanque que o livro não usa'
    END AS Motivo
FROM Dia d
INNER JOIN PST_Tanque t ON t.Id = d.IdLocalEstoque
INNER JOIN CAD_Mercadoria m ON m.Id = d.IdMercadoria

UNION ALL

SELECT
    'DETALHE' AS Parte,
    CONVERT(DATE, e.DataMovimentacao) AS Data,
    t.Numero AS Tanque,
    m.Id AS IdCombustivel,
    m.Descricao AS Combustivel,
    e.DocumentoOrigem AS Documento,
    CASE
        WHEN e.DocumentoOrigem LIKE 'AJ%' THEN 'AJUSTE_REGUA'
        WHEN CONVERT(DATE, df.DataMovimentacao) <> CONVERT(DATE, e.DataMovimentacao) THEN 'NOTA_DATA_DIFERENTE'
        ELSE 'LIVRO'
    END AS Tipo,
    CONVERT(DATE, df.DataMovimentacao) AS DataDocumento,
    NULL, NULL, NULL, NULL, NULL, NULL,
    CASE
        WHEN e.DocumentoOrigem LIKE 'AJ%'
        THEN 'Entra no tanque, não entra no livro | efeito '
           + CONVERT(VARCHAR(20), CASE WHEN e.Fluxo = 0 THEN e.Quantidade ELSE -e.Quantidade END)
        WHEN CONVERT(DATE, df.DataMovimentacao) <> CONVERT(DATE, e.DataMovimentacao)
        THEN 'Estoque ' + CONVERT(VARCHAR(10), e.DataMovimentacao, 103)
           + ' / documento ' + CONVERT(VARCHAR(10), df.DataMovimentacao, 103)
           + ' | efeito '
           + CONVERT(VARCHAR(20), CASE WHEN e.Fluxo = 0 THEN e.Quantidade ELSE -e.Quantidade END)
        ELSE 'Livro e tanque no mesmo dia'
    END AS Motivo
FROM EST_EstoqueFisicoAnalitico e
INNER JOIN PST_Tanque t ON t.Id = e.IdLocalEstoque
INNER JOIN CAD_Mercadoria m ON m.Id = e.IdMercadoria
OUTER APPLY
(
    SELECT TOP 1 df2.DataMovimentacao
    FROM FAT_DocumentoFiscal df2
    WHERE df2.IdEmpresa = e.IdEmpresa
      AND df2.Numero = e.DocumentoOrigem
    ORDER BY ABS(DATEDIFF(DAY, df2.DataMovimentacao, e.DataMovimentacao)), df2.Id
) df
WHERE e.IdEmpresa = @idEmpresa
  AND CONVERT(DATE, e.DataMovimentacao) = @data
  AND (@idCombustivel IS NULL OR e.IdMercadoria = @idCombustivel)
  AND (
        e.DocumentoOrigem LIKE 'AJ%'
     OR CONVERT(DATE, df.DataMovimentacao) <> CONVERT(DATE, e.DataMovimentacao)
      )

ORDER BY Parte DESC, Tanque, Documento;
