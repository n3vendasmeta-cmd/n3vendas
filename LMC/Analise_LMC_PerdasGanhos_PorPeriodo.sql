/*
Analise_LMC_PerdasGanhos_PorPeriodo.sql

1 - LMCS IMPRESSOS NO PERIODO
Mostra os LMCs gravados para empresa/combustível/período e quando foram impressos.

2 - CALCULO ATUAL LMC POR DIA
Mostra o recálculo atual do banco para perda/ganho dia a dia, incluindo estoque fechamento,
estoque esperado e diferença atual.

3 - MOVIMENTOS RETROATIVOS APOS IMPRESSAO
Mostra se houve movimentação com DataMovimentacao dentro do período do LMC,
mas DataRegistro posterior à impressão de cada dia.
*/

DECLARE @IdEmpresa BIGINT = 21573;
DECLARE @IdCombustivel BIGINT = 3052;
DECLARE @DataInicio DATE = '2025-12-01';
DECLARE @DataTermino DATE = '2025-12-30';

SELECT
    '1 - LMCS IMPRESSOS NO PERIODO' AS Evidencia,
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
  AND MC.Data BETWEEN @DataInicio AND @DataTermino
ORDER BY
    MC.Data;

SELECT
    '2 - CALCULO ATUAL LMC POR DIA' AS Evidencia,
    Dia,
    EstoqueInicial,
    VolumeRecebidoDia,
    SaidaBombaDia,
    MedicaoFinal AS EstoqueFechamentoAtual,
    CAST(EstoqueInicial + VolumeRecebidoDia - SaidaBombaDia AS DECIMAL(18,3)) AS EstoqueEsperado,
    CAST(MedicaoFinal - (EstoqueInicial + VolumeRecebidoDia - SaidaBombaDia) AS DECIMAL(18,3)) AS PerdaGanhoAtual,
    AfericaoDia,
    SobrasFaltasMes AS PerdaGanhoAcumuladoMes,
    Combustivel
FROM dbo.FN_PST_GetPerdasSobrasNasMedicoesDoTanque
(
    @IdEmpresa,
    CONVERT(VARCHAR(20), @IdCombustivel),
    @DataInicio,
    @DataTermino
)
ORDER BY
    Dia;

SELECT
    '3 - MOVIMENTOS RETROATIVOS APOS IMPRESSAO' AS Evidencia,
    EFA.DataMovimentacao,
    CONVERT(DATE, EFA.DataRegistro) AS DataRegistro,
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
INNER JOIN PST_MovimentacaoCombustivel MC
    ON MC.IdEmpresa = EFA.IdEmpresa
   AND MC.IdCombustivel = EFA.IdMercadoria
   AND MC.Data = EFA.DataMovimentacao
WHERE EFA.IdEmpresa = @IdEmpresa
  AND EFA.IdMercadoria = @IdCombustivel
  AND EFA.DataMovimentacao BETWEEN @DataInicio AND @DataTermino
  AND EFA.DataRegistro > MC.DataImpressao
GROUP BY
    EFA.DataMovimentacao,
    CONVERT(DATE, EFA.DataRegistro),
    EFA.IdLocalEstoque,
    TANQUE.Numero,
    EFA.Fluxo,
    DF.TipoDocumento,
    DF.Numero,
    DF.Status,
    DF.Cancelado
ORDER BY
    EFA.DataMovimentacao,
    DataRegistro,
    NumeroTanque,
    EFA.Fluxo,
    DF.Numero;
