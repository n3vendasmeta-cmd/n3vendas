/*
================================================================================
SCRIPT DE CORREÇÃO: Ajuste de Abastecimentos com Datas Inválidas/Antigas (1753-01-01)
CATEGORIA: LMC / Posto / Estoque
DESCRIÇÃO: 
  Corrige registros na tabela PDV_Abastecimento onde a coluna DiaHoraAbastecimento
  está gravada com datas inconsistentes/inválidas (ex: 1753-01-01). 
  
  Essas datas antigas fazem com que a regra da função:
  dbo.FN_PST_PodeRealizarLancamentoDeAjusteDeEstoqueParaOsCombustiveis
  entenda que sempre existem movimentações de abastecimento anteriores à data 
  selecionada no LMC, bloqueando indevidamente o Ajuste Inicial de Estoque.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. IDENTIFICAÇÃO E VALIDAÇÃO DOS REGISTROS AFETADOS
-- -----------------------------------------------------------------------------
DECLARE @IdEmpresa BIGINT = NULL; -- Deixe NULL para todas as empresas ou informe o Id específico (ex: 1)

SELECT 
    a.Id AS IdAbastecimento,
    a.DiaHoraAbastecimento AS DataInvalidaAtual,
    a.IdItemDocumentoFiscal,
    item.IdDocumentoFiscal,
    dados.IdEmpresa,
    dados.DataEmissao AS DataEmissaoDocumento,
    item.Cancelado AS ItemCancelado,
    cupom.Cancelado AS CupomCancelado
FROM PDV_Abastecimento a WITH (NOLOCK)
INNER JOIN PDV_ItemDocumentoFiscal item WITH (NOLOCK) 
    ON item.Id = a.IdItemDocumentoFiscal
INNER JOIN PDV_DocumentoFiscal cupom WITH (NOLOCK) 
    ON cupom.Id = item.IdDocumentoFiscal
INNER JOIN PDV_DadosBasicosDocumento dados WITH (NOLOCK) 
    ON dados.Id = cupom.InformacoesDocumento
WHERE a.DiaHoraAbastecimento < '1800-01-01'
  AND (@IdEmpresa IS NULL OR dados.IdEmpresa = @IdEmpresa)
ORDER BY a.Id;

GO

-- -----------------------------------------------------------------------------
-- 2. EXECUÇÃO DA CORREÇÃO (UTILIZANDO TRANSACTION)
-- -----------------------------------------------------------------------------
BEGIN TRANSACTION;

-- Atualiza a data do abastecimento com base na data de emissão do documento fiscal correspondente
UPDATE a
SET a.DiaHoraAbastecimento = dados.DataEmissao
FROM PDV_Abastecimento a
INNER JOIN PDV_ItemDocumentoFiscal item 
    ON item.Id = a.IdItemDocumentoFiscal
INNER JOIN PDV_DocumentoFiscal cupom 
    ON cupom.Id = item.IdDocumentoFiscal
INNER JOIN PDV_DadosBasicosDocumento dados 
    ON dados.Id = cupom.InformacoesDocumento
WHERE a.DiaHoraAbastecimento < '1800-01-01';

-- Valida os registros alterados após o Update
SELECT 
    a.Id AS IdAbastecimento,
    a.DiaHoraAbastecimento AS DataCorrigida,
    dados.IdEmpresa
FROM PDV_Abastecimento a WITH (NOLOCK)
INNER JOIN PDV_ItemDocumentoFiscal item WITH (NOLOCK) 
    ON item.Id = a.IdItemDocumentoFiscal
INNER JOIN PDV_DocumentoFiscal cupom WITH (NOLOCK) 
    ON cupom.Id = item.IdDocumentoFiscal
INNER JOIN PDV_DadosBasicosDocumento dados WITH (NOLOCK) 
    ON dados.Id = cupom.InformacoesDocumento
WHERE a.DiaHoraAbastecimento >= '1800-01-01';

-- Se a validação estiver OK:
-- COMMIT TRANSACTION;

-- Se houver qualquer inconsistência:
-- ROLLBACK TRANSACTION;

GO

-- -----------------------------------------------------------------------------
-- 3. TESTE DE VALIDAÇÃO DA FUNÇÃO DO LMC
-- -----------------------------------------------------------------------------
DECLARE @IdEmpresa BIGINT = 1; -- Informar o Id da empresa
DECLARE @DataLMC DATE = '2026-08-20'; -- Informar a data desejada para o LMC

SELECT dbo.FN_PST_PodeRealizarLancamentoDeAjusteDeEstoqueParaOsCombustiveis(@DataLMC, @IdEmpresa) AS PodeAjustar;
-- Retorno Esperado: 1 (Permitido realizar ajuste inicial)
