DECLARE @Cnpj VARCHAR(14) = '05048982000105';
DECLARE @DataReinicio DATETIME = '2026-07-16 16:38:00';

-- 1. Verifica se a empresa está habilitada na integração
SELECT *
FROM [Integracao.Ipiranga].FN_CFG_ObterEmpresaHabilitadasIntegracaoIpiranga()
WHERE Cnpj = @Cnpj;

-- 2. Verifica serviço global Ipiranga
SELECT
    Id,
    Descricao,
    ServicoGlobal,
    Habilitado,
    IdEmpresa
FROM CFG_ServicosGlobal
WHERE ServicoGlobal = 41;

-- 3. Conta pendentes
SELECT
    COUNT(*) AS QtdPendentes,
    MIN(doc.HoraEmissao) AS VendaMaisAntiga,
    MAX(doc.HoraEmissao) AS VendaMaisRecente
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND COALESCE(ipi.Enviado, 0) = 0
  AND COALESCE(ipi.PermiteReenvio, 1) = 1;

-- 4. Lista os primeiros pendentes da fila
SELECT TOP 100
    ipi.Id,
    doc.HoraEmissao,
    ipi.DataRecebimento,
    ipi.DataEnvio,
    ipi.Enviado,
    ipi.PermiteReenvio,
    doc.Status,
    CASE doc.Status
        WHEN 0 THEN 'Memoria'
        WHEN 1 THEN 'Processado'
        WHEN 2 THEN 'Estornado'
        WHEN 3 THEN 'Cancelado'
        WHEN 4 THEN 'Inutilizado'
        WHEN 5 THEN 'Denegado'
        WHEN 6 THEN 'Complementar'
        WHEN 7 THEN 'Encerrado'
        ELSE 'Status desconhecido'
    END AS DescricaoStatus,
    doc.Numero,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND COALESCE(ipi.Enviado, 0) = 0
  AND COALESCE(ipi.PermiteReenvio, 1) = 1
ORDER BY doc.HoraEmissao ASC;

-- 4.1. Diagnostica por que pendentes podem não entrar na fila real de envio
SELECT TOP 100
    ipi.Id,
    doc.HoraEmissao,
    ipi.DataRecebimento,
    ipi.DataEnvio,
    ipi.Enviado,
    ipi.PermiteReenvio,
    doc.Status,
    CASE doc.Status
        WHEN 0 THEN 'Memoria'
        WHEN 1 THEN 'Processado'
        WHEN 2 THEN 'Estornado'
        WHEN 3 THEN 'Cancelado'
        WHEN 4 THEN 'Inutilizado'
        WHEN 5 THEN 'Denegado'
        WHEN 6 THEN 'Complementar'
        WHEN 7 THEN 'Encerrado'
        ELSE 'Status desconhecido'
    END AS DescricaoStatus,
    doc.Numero,
    doc.IdEmpresa,
    CASE WHEN doc.Status NOT IN (1, 3) THEN 'BLOQUEIA: Status fora de 1/3' END AS ValidaStatus,
    CASE WHEN doc.Numero IS NULL THEN 'BLOQUEIA: Numero fiscal NULL' END AS ValidaNumero,
    CASE WHEN pdv.Id IS NULL THEN 'BLOQUEIA: sem PDV_DocumentoFiscal' END AS ValidaDocumentoPDV,
    CASE WHEN cfg.Id IS NULL THEN 'BLOQUEIA: sem CFG_ConfiguracoesEmpresa' END AS ValidaConfiguracaoEmpresa,
    CASE WHEN ipcfg.Id IS NULL THEN 'BLOQUEIA: sem CFG_IntegracaoIpiranga' END AS ValidaConfiguracaoIpiranga
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
LEFT JOIN PDV_DocumentoFiscal pdv ON pdv.Id = ipi.Id
LEFT JOIN CFG_ConfiguracoesEmpresa cfg ON cfg.IdEmpresa = doc.IdEmpresa
LEFT JOIN CFG_IntegracaoIpiranga ipcfg ON ipcfg.Id = cfg.Id
WHERE emp.CpfCnpj = @Cnpj
  AND COALESCE(ipi.Enviado, 0) = 0
  AND COALESCE(ipi.PermiteReenvio, 1) = 1
ORDER BY doc.HoraEmissao ASC;

-- 5. Simula o lote que o serviço busca
SELECT TOP 200 *
FROM [Integracao.Ipiranga].FN_PDV_ObterDocumentoFiscaisNaoEnviadosIpiranga();

-- 5.1. Simula o lote que o serviço busca somente para a empresa
-- Se der erro no campo CNPJ, rode o passo 5 e confira o nome da coluna retornada pela função.
SELECT TOP 200 f.*
FROM [Integracao.Ipiranga].FN_PDV_ObterDocumentoFiscaisNaoEnviadosIpiranga() f
WHERE f.cnpjLoja = @Cnpj
ORDER BY f.dataVenda ASC;

-- 6. Procura documentos pendentes com item zerado que podem gerar divisão por zero
SELECT DISTINCT
    ipi.Id AS IdDocumentoFiscal,
    doc.HoraEmissao,
    item.Id AS IdItem,
    item.IdMercadoria,
    item.DescricaoMercadoria,
    item.Quantidade,
    item.ValorUnitario,
    item.TotalItemSemDesconto,
    item.Desconto,
    item.Acrescimo
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN FAT_ItemDocumentoFiscal item ON item.IdDocumentoFiscal = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND COALESCE(ipi.Enviado, 0) = 0
  AND COALESCE(ipi.PermiteReenvio, 1) = 1
  AND COALESCE(item.TotalItemSemDesconto, 0) = 0
ORDER BY doc.HoraEmissao;

-- 7. Verifica o que foi tentado após determinado horário
SELECT COUNT(*) AS QtdTentadasAposReinicio
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND ipi.DataEnvio >= @DataReinicio;

-- 8. Lista últimas tentativas
SELECT TOP 100
    ipi.Id,
    doc.HoraEmissao,
    ipi.DataEnvio,
    ipi.Enviado,
    ipi.PermiteReenvio,
    doc.Status,
    CASE doc.Status
        WHEN 0 THEN 'Memoria'
        WHEN 1 THEN 'Processado'
        WHEN 2 THEN 'Estornado'
        WHEN 3 THEN 'Cancelado'
        WHEN 4 THEN 'Inutilizado'
        WHEN 5 THEN 'Denegado'
        WHEN 6 THEN 'Complementar'
        WHEN 7 THEN 'Encerrado'
        ELSE 'Status desconhecido'
    END AS DescricaoStatus,
    doc.Numero,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
ORDER BY ipi.DataEnvio DESC;

-- 9. Paliativo para retirar documento específico da fila, somente após confirmar que não é elegível para envio
-- Exemplos: Status = 4 / Inutilizado, Numero fiscal NULL ou item zerado.
-- Ajuste o Id antes de executar.
/*
UPDATE [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga
SET PermiteReenvio = 0,
    DataEnvio = GETDATE(),
    DadosRetorno = 'Retirado da fila: documento não elegível para envio Ipiranga conforme regra atual. Status fora de 1/3, Numero fiscal NULL ou item zerado.'
WHERE Id = 8723491;
*/

/*

Paliativo para retirar um documento específico da fila, se estiver travando:
UPDATE [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga
SET PermiteReenvio = 0,
    DataEnvio = GETDATE(),
    DadosRetorno = 'Retirado temporariamente da fila: documento com item zerado causando erro no envio de Sales.'
WHERE Id = 8723491;
*/
