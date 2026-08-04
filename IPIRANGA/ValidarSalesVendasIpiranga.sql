DECLARE @Cnpj VARCHAR(14) = '09262475000120';
DECLARE @DataReinicio DATETIME = DATEADD(MINUTE, -30, GETDATE());

/* 1. Empresa habilitada na integração */
SELECT *
FROM [Integracao.Ipiranga].FN_CFG_ObterEmpresaHabilitadasIntegracaoIpiranga()
WHERE Cnpj = @Cnpj;

/* 2. Serviço global Ipiranga */
SELECT
    Id,
    Descricao,
    ServicoGlobal,
    Habilitado,
    IdEmpresa
FROM CFG_ServicosGlobal
WHERE ServicoGlobal = 41;

/* 3. Resumo geral por tipo */
SELECT
    CASE
        WHEN ipi.Enviado = 0 AND ipi.PermiteReenvio = 1 THEN 'Pendente na fila/reenvio'
        WHEN ipi.DadosRetorno LIKE '%504%' THEN '504 Gateway Timeout'
        WHEN ipi.DadosRetorno LIKE '%502%' THEN '502 Bad Gateway'
        WHEN ipi.DadosRetorno LIKE '%500%' THEN '500 Server/Internal'
        WHEN ipi.DadosRetorno LIKE '400%' THEN '400 Validacao'
        WHEN ipi.DadosRetorno LIKE '%Um ou mais erros%' THEN 'Um ou mais erros'
        WHEN ipi.DadosRetorno LIKE '%converting value%' THEN 'Erro conversao'
        WHEN ipi.DadosRetorno IS NULL THEN 'Sem retorno'
        ELSE 'Outro'
    END AS Situacao,
    COUNT(*) AS Quantidade,
    MIN(doc.HoraEmissao) AS VendaMaisAntiga,
    MAX(doc.HoraEmissao) AS VendaMaisRecente
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND doc.Status = 1
  AND doc.Numero IS NOT NULL
  AND ipi.Enviado = 0
  AND (
        ipi.PermiteReenvio = 1
        OR ipi.DadosRetorno NOT LIKE '202 - Accepted%'
      )
GROUP BY
    CASE
        WHEN ipi.Enviado = 0 AND ipi.PermiteReenvio = 1 THEN 'Pendente na fila/reenvio'
        WHEN ipi.DadosRetorno LIKE '%504%' THEN '504 Gateway Timeout'
        WHEN ipi.DadosRetorno LIKE '%502%' THEN '502 Bad Gateway'
        WHEN ipi.DadosRetorno LIKE '%500%' THEN '500 Server/Internal'
        WHEN ipi.DadosRetorno LIKE '400%' THEN '400 Validacao'
        WHEN ipi.DadosRetorno LIKE '%Um ou mais erros%' THEN 'Um ou mais erros'
        WHEN ipi.DadosRetorno LIKE '%converting value%' THEN 'Erro conversao'
        WHEN ipi.DadosRetorno IS NULL THEN 'Sem retorno'
        ELSE 'Outro'
    END
ORDER BY Quantidade DESC;

/* 4. Fila real que o serviço busca */
SELECT TOP 200 f.*
FROM [Integracao.Ipiranga].FN_PDV_ObterDocumentoFiscaisNaoEnviadosIpiranga() f
WHERE f.cnpjComponente = @Cnpj
ORDER BY f.dataVenda ASC;

/* 5. Pendentes item a item */
SELECT TOP 500
    ipi.Id,
    doc.HoraEmissao,
    doc.Numero,
    ipi.Enviado,
    ipi.PermiteReenvio,
    ipi.DataEnvio,
    CASE
        WHEN ipi.Enviado = 0 AND ipi.PermiteReenvio = 1 THEN 'Pendente na fila/reenvio'
        WHEN ipi.DadosRetorno LIKE '%504%' THEN '504 Gateway Timeout'
        WHEN ipi.DadosRetorno LIKE '%502%' THEN '502 Bad Gateway'
        WHEN ipi.DadosRetorno LIKE '%500%' THEN '500 Server/Internal'
        WHEN ipi.DadosRetorno LIKE '400%' THEN '400 Validacao'
        WHEN ipi.DadosRetorno LIKE '%Um ou mais erros%' THEN 'Um ou mais erros'
        WHEN ipi.DadosRetorno LIKE '%converting value%' THEN 'Erro conversao'
        WHEN ipi.DadosRetorno IS NULL THEN 'Sem retorno'
        ELSE 'Outro'
    END AS Situacao,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND doc.Status = 1
  AND doc.Numero IS NOT NULL
  AND ipi.Enviado = 0
  AND (
        ipi.PermiteReenvio = 1
        OR ipi.DadosRetorno NOT LIKE '202 - Accepted%'
      )
ORDER BY doc.HoraEmissao DESC;

/* 6. Últimas tentativas após horário informado */
SELECT TOP 200
    ipi.Id,
    doc.HoraEmissao,
    doc.Numero,
    ipi.Enviado,
    ipi.PermiteReenvio,
    ipi.DataEnvio,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND ipi.DataEnvio >= @DataReinicio
ORDER BY ipi.DataEnvio DESC;

/* 7. Diagnóstico 400 - modalidade inválida */
SELECT
    ipi.Id,
    doc.Numero,
    pagamento.TipoFinalizadora,
    pagamento.Descricao,
    pagamento.ValorPago,
    cartao.TipoModalidadeTransacao,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
INNER JOIN PDV_PagamentoDocumentoFiscal pagamento ON pagamento.IdDocumentoFiscal = ipi.Id
LEFT JOIN PDV_PagamentoDocumentoFiscalCartao cartao
    ON cartao.IdPagamentoDocumentoFiscal = pagamento.Id
WHERE emp.CpfCnpj = @Cnpj
  AND ipi.Enviado = 0
  AND ipi.DadosRetorno LIKE '%modalidades > modalidade%'
ORDER BY doc.HoraEmissao DESC;

/* 8. Diagnóstico 400 - unidade inválida */
SELECT
    ipi.Id,
    doc.Numero,
    item.NumeroSequencial,
    item.DescricaoMercadoria,
    item.UnidadeVendaMercadoria,
    ipi.DadosRetorno
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
INNER JOIN FAT_ItemDocumentoFiscal item ON item.IdDocumentoFiscal = ipi.Id
WHERE emp.CpfCnpj = @Cnpj
  AND ipi.Enviado = 0
  AND ipi.DadosRetorno LIKE '%unidadeMedidaProduto%'
ORDER BY doc.HoraEmissao DESC;

/* 9. Valida definição atual das functions */
SELECT OBJECT_DEFINITION(
    OBJECT_ID('[Integracao.Ipiranga].FN_PDV_ObterPagamentosDocumentoFiscaisNaoEnviadoIpiranga')
) AS DefinicaoFunctionPagamento;

SELECT OBJECT_DEFINITION(
    OBJECT_ID('[Integracao.Ipiranga].FN_PDV_ObterItemDocumentoFiscaisNaoEnviadoIpiranga')
) AS DefinicaoFunctionItem;

/* 10. PALIATIVO - corrigir Vale como modalidade 92 */
/*
ALTER FUNCTION [Integracao.Ipiranga].FN_PDV_ObterPagamentosDocumentoFiscaisNaoEnviadoIpiranga(@idDocumento BIGINT)
RETURNS TABLE RETURN
(
    SELECT 
        CONVERT(DECIMAL(19,2), COALESCE(pagamento.ValorPago,0)) AS valorPago,
        CASE pagamento.TipoFinalizadora 
            WHEN 0 THEN '99'
            WHEN 1 THEN '3'
            WHEN 2 THEN (CASE cartao.TipoModalidadeTransacao WHEN 1 THEN '91' WHEN 2 THEN '90' ELSE '00' END)
            WHEN 3 THEN '92'
            WHEN 6 THEN '92'
            WHEN 41 THEN (CASE pagamento.Descricao WHEN 'AbasteceAi - Pix' THEN '55' ELSE '46' END)
            ELSE '00'
        END AS modalidade
    FROM PDV_PagamentoDocumentoFiscal pagamento
    LEFT JOIN PDV_PagamentoDocumentoFiscalCartao cartao 
        ON cartao.IdPagamentoDocumentoFiscal = pagamento.Id
    WHERE pagamento.IdDocumentoFiscal = @idDocumento
);
*/

/* 11. PALIATIVO - corrigir unidade KT como UN */
/*
ALTER FUNCTION [Integracao.Ipiranga].FN_PDV_ObterItemDocumentoFiscaisNaoEnviadoIpiranga(@idDocumento BIGINT)
RETURNS TABLE RETURN
(
    SELECT 
        item.IdMercadoria,
        item.DescricaoMercadoria,
        CONVERT(DECIMAL(19,3),(item.TotalItemLiquido / item.ValorUnitario)) AS quantidade,
        CONVERT(DECIMAL(19,2), COALESCE(item.ValorUnitario,0)) AS valorUnitario,
        CONVERT(DECIMAL(19,2), COALESCE(item.TotalItemLiquido,0)) AS valorCupom,
        'S' AS produtoIpiranga,
        CASE 
            WHEN item.UnidadeVendaMercadoria = 'KT' THEN 'UN'
            WHEN item.UnidadeVendaMercadoria = 'LT' THEN 'L'
            ELSE item.UnidadeVendaMercadoria
        END AS unidadeMedidaProduto,
        item.NumeroSequencial AS numeroSequencialItemNota,
        COALESCE(produto.codigoProduto, item.CodigoBarraMercadoria) AS codigoInternoIpirangaProduto,
        CONVERT(DECIMAL(19,2), COALESCE(item.Desconto,0)) AS valorDesconto,
        CONVERT(DECIMAL(19,2), COALESCE(item.Acrescimo,0)) AS valorAcrescimo,
        CONVERT(DECIMAL(19,2), (COALESCE(item.Desconto,0) * 100) / CONVERT(DECIMAL(19,2), COALESCE(item.TotalItemSemDesconto,0))) AS percentualDesconto,
        CONVERT(DECIMAL(19,2), (COALESCE(item.Acrescimo,0) * 100) / CONVERT(DECIMAL(19,2), COALESCE(item.TotalItemSemDesconto,0))) AS percentualAcrescimo,
        CASE produto.estoque WHEN 'P' THEN 1 WHEN 'L' THEN '2' WHEN 'J' THEN '5' ELSE '1' END CodigoComponente, 
        CASE produto.estoque WHEN 'P' THEN '999' WHEN 'J' THEN '500' ELSE CONVERT(VARCHAR, FORMAT(dadosBasicos.NumeroCaixa, 'd3')) END AS NumeroPDV,
        item.DescricaoMercadoria AS descricaoInternaIpirangaProduto,
        anp.Codigo AS codigoProdutoANP
    FROM FAT_ItemDocumentoFiscal item
    LEFT JOIN [Integracao.Ipiranga].[ProdutoIpiranga] produto ON produto.IdMercadoria = item.IdMercadoria
    INNER JOIN PDV_DocumentoFiscal documentoPDV ON documentoPDV.Id = item.IdDocumentoFiscal
    INNER JOIN PDV_DadosBasicosDocumento dadosBasicos ON dadosBasicos.Id = documentoPDV.InformacoesDocumento
    LEFT JOIN PST_Combustivel combustivel ON combustivel.Id = item.IdMercadoria
    LEFT JOIN CAD_MercadoriaEstocavel me ON combustivel.Id = me.Id
    LEFT JOIN PST_TabelaAnp anp ON anp.Id = me.IdTabelaAnp
    WHERE item.IdDocumentoFiscal = @idDocumento
);
*/

/* 12. Liberar 400 para reenvio depois dos paliativos */
/*
UPDATE ipi
SET
    PermiteReenvio = 1,
    DadosRetorno = 'Liberado para reenvio N3 - correcao paliativa 400 Validacao'
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND doc.Status = 1
  AND doc.Numero IS NOT NULL
  AND ipi.Enviado = 0
  AND ipi.DadosRetorno LIKE '400%';
*/

/* 13. Liberar erro 500 para reenvio, se decidir testar */
/*
UPDATE ipi
SET
    PermiteReenvio = 1,
    DadosRetorno = 'Liberado para reenvio N3 - erro 500 Server/Internal'
FROM [Integracao.Ipiranga].PDV_DocumentoFiscalIpiranga ipi
INNER JOIN VIEW_FAT_DocumentoFiscalVendaTodosStatus doc ON doc.Id = ipi.Id
INNER JOIN CAD_ParceiroNegocio emp ON emp.Id = doc.IdEmpresa
WHERE emp.CpfCnpj = @Cnpj
  AND doc.Status = 1
  AND doc.Numero IS NOT NULL
  AND ipi.Enviado = 0
  AND ipi.DadosRetorno LIKE '%500%';
*/
