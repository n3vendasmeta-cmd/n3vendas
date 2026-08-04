DECLARE @IdEmpresa BIGINT = 1;
DECLARE @Data DATE = '2026-08-04';
DECLARE @BancoMetaPista SYSNAME = 'BDMetaPista';
DECLARE @BancoRetaguarda SYSNAME = 'SDENGENHARIA';
------------------------------------------------------------
-- BANCO METAPISTA
-- Objetivo: validar se o Pista leu o tanque e se marcou/envou
-- a regua para criacao na retaguarda.
------------------------------------------------------------

USE BDMetaPista;

-- 1. Leituras automaticas do dia
SELECT TOP 100
    h.Id,
    h.IdTanque,
    h.DataHora,
    h.EstoqueFisico,
    h.CriarReguaRetaguarda,
    h.CriadoReguaRetaguarda,
    h.MensagemRetornoCriacaoRegua
FROM HistoricoLeituraAutomaticaEstoque h
WHERE CAST(h.DataHora AS DATE) = @Data
ORDER BY h.DataHora DESC, h.IdTanque;

-- 2. Ultima leitura de cada tanque no dia
WITH Ultimas AS (
    SELECT
        h.IdTanque,
        MAX(h.DataHora) AS UltimaDataHora
    FROM HistoricoLeituraAutomaticaEstoque h
    WHERE CAST(h.DataHora AS DATE) = @Data
    GROUP BY h.IdTanque
)
SELECT
    h.Id,
    h.IdTanque,
    h.DataHora,
    h.EstoqueFisico,
    h.CriarReguaRetaguarda,
    h.CriadoReguaRetaguarda,
    h.MensagemRetornoCriacaoRegua
FROM HistoricoLeituraAutomaticaEstoque h
INNER JOIN Ultimas u
    ON u.IdTanque = h.IdTanque
   AND u.UltimaDataHora = h.DataHora
ORDER BY h.IdTanque;

-- 3. Leituras pendentes de envio para retaguarda
SELECT *
FROM FN_ObterLeiturasPendentesEnvioRegua()
ORDER BY DataHora DESC;

-- 4. Resumo das leituras do dia
SELECT
    CASE
        WHEN CriarReguaRetaguarda = 0 THEN 'Leu, mas nao marcou para enviar'
        WHEN CriarReguaRetaguarda = 1 AND COALESCE(CriadoReguaRetaguarda, 0) = 0 THEN 'Marcado, mas nao criado na retaguarda'
        WHEN CriarReguaRetaguarda = 1 AND CriadoReguaRetaguarda = 1 THEN 'Criado na retaguarda'
        ELSE 'Outro'
    END AS Situacao,
    COUNT(*) AS Quantidade
FROM HistoricoLeituraAutomaticaEstoque
WHERE CAST(DataHora AS DATE) = @Data
GROUP BY
    CASE
        WHEN CriarReguaRetaguarda = 0 THEN 'Leu, mas nao marcou para enviar'
        WHEN CriarReguaRetaguarda = 1 AND COALESCE(CriadoReguaRetaguarda, 0) = 0 THEN 'Marcado, mas nao criado na retaguarda'
        WHEN CriarReguaRetaguarda = 1 AND CriadoReguaRetaguarda = 1 THEN 'Criado na retaguarda'
        ELSE 'Outro'
    END;

------------------------------------------------------------
-- BANCO RETAGUARDA
-- Objetivo: validar configuracao e se a regua foi criada.
------------------------------------------------------------

USE SDENGENHARIA;

-- 5. Empresa habilitada para lancamento automatico
SELECT *
FROM FN_ObterEmpresasHabilitadasParaLancamentoReguaAutomatica()
WHERE Id = @IdEmpresa;

-- 6. Configuracao LMC
SELECT
    IdEmpresa,
    RealizaLeituraTanques,
    HorarioMedicaoTanque,
    TipoLancamentoMedicaoTanque
FROM CFG_ConfiguracoesLivroMovimentacaoCombustivel
WHERE IdEmpresa = @IdEmpresa;

-- 7. Servico global de verificacao de estoque por medidor
SELECT
    Id,
    Descricao,
    ServicoGlobal,
    Habilitado,
    IdEmpresa
FROM CFG_ServicosGlobal
WHERE IdEmpresa = @IdEmpresa
  AND ServicoGlobal = 15;

-- 8. Tanques configurados para regua automatica
SELECT *
FROM [Venda].FN_GetInformacoesReguaAutomatica(@IdEmpresa)
ORDER BY IdTanque;

-- 9. Reguas criadas no dia
SELECT
    Id,
    IdTanque,
    ValorRegua,
    Status,
    DataLancamento,
    IdEmpresa,
    EstoqueSistema,
    EstoqueMedidor,
    EstoqueMedidor - EstoqueSistema AS Diferenca
FROM PST_ReguaAutomatica
WHERE IdEmpresa = @IdEmpresa
  AND CAST(DataLancamento AS DATE) = @Data
ORDER BY DataLancamento DESC;

-- 10. Validacao da diferenca das reguas criadas
SELECT
    IdTanque,
    DataLancamento,
    EstoqueSistema,
    EstoqueMedidor,
    EstoqueMedidor - EstoqueSistema AS Diferenca,
    CASE
        WHEN ABS(EstoqueMedidor - EstoqueSistema) > 1000 THEN 'Acima de 1000 litros'
        ELSE 'Dentro do limite'
    END AS ValidacaoDiferenca
FROM PST_ReguaAutomatica
WHERE IdEmpresa = @IdEmpresa
  AND CAST(DataLancamento AS DATE) = @Data
ORDER BY IdTanque;
