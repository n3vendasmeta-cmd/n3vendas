DECLARE @Cnpj VARCHAR(14) = '05048982000105';

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
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND COALESCE(ipi.Enviado, 0) = 0
  AND COALESCE(ipi.PermiteReenvio, 1) = 1
ORDER BY doc.HoraEmissao ASC;

-- 5. Simula o lote que o serviço busca
SELECT TOP 200 *
FROM [Integracao.Ipiranga].FN_PDV_ObterDocumentoFiscaisNaoEnviadosIpiranga();

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
DECLARE @DataReinicio DATETIME = '2026-07-16 16:38:00';

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
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
ORDER BY ipi.DataEnvio DESC;

--Paliativo para retirar um documento específico da fila, se estiver travando:
UPDATE [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga
SET PermiteReenvio = 0,
    DataEnvio = GETDATE(),
    DadosRetorno = 'Retirado temporariamente da fila: documento com item zerado causando erro no envio de Sales.'
WHERE Id = 8723491;
