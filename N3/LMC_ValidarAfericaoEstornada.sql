/*
    Biblioteca SQL - N3
    Nome: N3_LMC_ValidarAfericaoEstornada.sql
    Objetivo:
        Validar se uma afericao estornada ainda esta sendo considerada no LMC.

    Como usar:
        1. Executar no banco METAPOSTO_GLOBAL do cliente.
        2. Ajustar os parametros abaixo conforme o caso.
        3. Conferir os campos Resultado nas tres consultas.

    Resultado esperado para afericao corretamente estornada:
        1 - Registro na PDV_Afericao: Estornada = 1
        2 - Retorno FN_PST_GetAfericoes: QuantidadeRetornada = 0
        3 - Retorno LMC agrupado: Afericao = 0.000
*/

DECLARE @NumeroAbastecimento BIGINT = 10664288;
DECLARE @Data DATE = '2026-08-31';
DECLARE @IdEmpresa BIGINT = 1;
DECLARE @IdCombustivel BIGINT = 625;
DECLARE @Tanque INT = 3;
DECLARE @Bico INT = 4;
DECLARE @PegarValorTotalDocumentoFiscal BIT = 0;

SELECT
    '1 - Registro na PDV_Afericao' AS Validacao,
    a.Id,
    a.NumeroAbastecimento,
    a.DiaHoraAbastecimento,
    a.Tanque,
    a.Bico,
    a.Litros,
    a.Total,
    a.Estornada,
    CASE
        WHEN COALESCE(a.Estornada, 0) = 1
            THEN 'OK - Afericao esta estornada'
        ELSE 'ERRO - Afericao nao esta estornada'
    END AS Resultado
FROM PDV_Afericao a WITH (NOLOCK)
WHERE a.NumeroAbastecimento = @NumeroAbastecimento;

SELECT
    '2 - Retorno FN_PST_GetAfericoes' AS Validacao,
    COUNT(*) AS QuantidadeRetornada,
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK - Afericao estornada nao retornou na funcao'
        ELSE 'ERRO - Afericao ainda retorna na funcao'
    END AS Resultado
FROM dbo.FN_PST_GetAfericoes(@Data, @Data, @IdEmpresa, @IdCombustivel, 0)
WHERE NumeroAbastecimento = @NumeroAbastecimento;

DECLARE @tabelaFiltro FiltroAbastecimentoLMC;

INSERT INTO @tabelaFiltro
(
    DataInicio,
    DataTermino,
    IdEmpresa,
    IdCombustivel,
    PegarValorTotalDocumentoFiscal
)
VALUES
(
    @Data,
    @Data,
    @IdEmpresa,
    @IdCombustivel,
    @PegarValorTotalDocumentoFiscal
);

SELECT
    '3 - Retorno LMC agrupado' AS Validacao,
    Tanque,
    Bico,
    DataAbastecimento,
    VendaCaixa,
    Afericao,
    CASE
        WHEN COALESCE(Afericao, 0) = 0
            THEN 'OK - LMC esta sem volume de afericao'
        ELSE 'ERRO - LMC ainda possui volume de afericao'
    END AS Resultado
FROM dbo.FN_PST_GetAbastecimentosAgrupadoPorBicoComBicoSemVenda(@tabelaFiltro)
WHERE Tanque = @Tanque
  AND Bico = @Bico
  AND DataAbastecimento = @Data
  AND IdentificadorCombustivel = @IdCombustivel;
