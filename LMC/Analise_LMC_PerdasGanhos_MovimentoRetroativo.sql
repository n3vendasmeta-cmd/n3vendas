/*1 - LMC IMPRESSO
Mostra se existe LMC gravado para empresa/combustível/data e quando foi impresso.

2 - CALCULO ATUAL LMC
Mostra o recálculo atual do banco para perda/ganho.

3 - AJUSTES REGUA/TANQUE
Mostra os lançamentos de variação de temperatura/régua por tanque.

4 - MOVIMENTOS RETROATIVOS APOS IMPRESSAO
Mostra se houve movimentação com DataMovimentacao da data do LMC,
mas DataRegistro posterior à impressão.
*/

DECLARE @IdEmpresa BIGINT = 21573;
DECLARE @IdCombustivel BIGINT = 5046;
DECLARE @Data DATE = '2025-12-20';

SELECT
    '1 - LMC IMPRESSO' AS Evidencia,
    MC.Id,
    EMP.ApelidoFantasia AS Empresa,
    EMP.CpfCnpj,
    COMB.Descricao AS Combustivel,
    MC.Data,
    MC.NumeroFolha,
    MC.DataImpressao
FROM PST_MovimentacaoCombustivel MC
INNER JOIN CAD_ParceiroNegocio EMP
    ON EMP.Id = MC.IdEmpresa
INNER JOIN CAD_Mercadoria COMB
    ON COMB.Id = MC.IdCombustivel
WHERE MC.IdEmpresa = @IdEmpresa
  AND MC.IdCombustivel = @IdCombustivel
  AND MC.Data = @Data;

SELECT
    '2 - CALCULO ATUAL LMC' AS Evidencia,
    EstoqueInicialDia,
    VolumeRecebidoDia,
    MedicaoFinal AS EstoqueFechamentoAtual,
    VariacaoEstoqueDia,
    SaidaBombaDia,
    SobrasFaltasDia AS PerdaGanhoAtual,
    Combustivel
FROM dbo.FN_PST_Relatorio0029_PerdasGanhosCombustivel
(
    @IdEmpresa,
    CONVERT(VARCHAR(20), @IdCombustivel),
    @Data
);

SELECT
    '3 - AJUSTES REGUA/TANQUE' AS Evidencia,
    A.NumeroTanque,
    A.Capacidade,
    A.NumeroNota,
    A.DataMovimentacao,
    A.Fluxo,
    A.Quantidade,
    CASE
        WHEN A.Fluxo = 0 THEN A.Quantidade
        ELSE A.Quantidade * -1
    END AS ImpactoPerdaGanho
FROM dbo.FN_PST_PegarAjustesDeEstoqueDeVariacaoDeTemperaturaPorTanque
(
    @IdEmpresa,
    CONVERT(VARCHAR(20), @IdCombustivel),
    @Data,
    @Data
) A
ORDER BY
    A.NumeroTanque,
    A.Fluxo;

SELECT
    '4 - MOVIMENTOS RETROATIVOS APOS IMPRESSAO' AS Evidencia,
    CONVERT(DATE, EFA.DataRegistro) AS DataRegistro,
    EFA.DataMovimentacao,
    EFA.IdLocalEstoque AS IdTanque,
    TANQUE.Numero AS NumeroTanque,
    EFA.Fluxo,
    DF.TipoDocumento,
    DF.Numero AS NumeroDocumento,
    DF.Status AS StatusDocumento,
    DF.Cancelado,
    SUM(EFA.Quantidade) AS Quantidade,
    SUM
    (
        CASE
            WHEN EFA.Fluxo = 0 THEN EFA.Quantidade
            ELSE EFA.Quantidade * -1
        END
    ) AS ImpactoSaldo
FROM EST_EstoqueFisicoAnalitico EFA
LEFT JOIN PST_Tanque TANQUE
    ON TANQUE.Id = EFA.IdLocalEstoque
LEFT JOIN FAT_ItemDocumentoFiscal IDF
    ON IDF.Id = EFA.ItemDocumentoOrigem
LEFT JOIN FAT_DocumentoFiscal DF
    ON DF.Id = IDF.IdDocumentoFiscal
CROSS APPLY
(
    SELECT TOP 1
        MC.DataImpressao
    FROM PST_MovimentacaoCombustivel MC
    WHERE MC.IdEmpresa = @IdEmpresa
      AND MC.IdCombustivel = @IdCombustivel
      AND MC.Data = @Data
) LMC
WHERE EFA.IdEmpresa = @IdEmpresa
  AND EFA.IdMercadoria = @IdCombustivel
  AND EFA.DataMovimentacao = @Data
  AND EFA.DataRegistro > LMC.DataImpressao
GROUP BY
    CONVERT(DATE, EFA.DataRegistro),
    EFA.DataMovimentacao,
    EFA.IdLocalEstoque,
    TANQUE.Numero,
    EFA.Fluxo,
    DF.TipoDocumento,
    DF.Numero,
    DF.Status,
    DF.Cancelado
ORDER BY
    DataRegistro,
    NumeroTanque,
    EFA.Fluxo,
    DF.Numero;
