DECLARE @IdEmpresa BIGINT = 289;
DECLARE @DataInicio DATE = '2026-07-07';
DECLARE @DataTermino DATE = '2026-07-10';

-- Se a BR informar o codigo SAP/chaveCliente da loja, preencher aqui.
-- Caso não saiba, deixa NULL apenas para conferência técnica do conteúdo.
DECLARE @ChaveCliente VARCHAR(50) = NULL;

SELECT
    doc.Id AS IdDocumentoFiscal,
    CONVERT(DATE, doc.DataMovimentacao) AS DataMovimento,
    doc.Numero AS NumeroCupom,
    docPDV.DataEnvioBRMania,
    docPDV.RetornoBRMania,

    (
        SELECT
            @ChaveCliente AS chaveCliente,
            'Metanet Sistemas' AS empresaTransmissao,
            'Metanet' AS sistemaTransmissao,
            CONVERT(VARCHAR(19), docPDV.DataEnvioBRMania, 120) AS dataTransmissao,

            JSON_QUERY((
                SELECT
                    doc.ChaveAcesso AS chaveAcessoDFe,
                    CONVERT(VARCHAR(19), COALESCE(doc.HoraEmissao, doc.DataEmissao), 120) AS dataCupom,
                    CONVERT(VARCHAR(19), doc.DataMovimentacao, 120) AS dataMovimento,
                    COALESCE(doc.Numero, 0) AS numeroCupom,
                    CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,2), docPDV.Subtotal)) AS valorCupomFiscal,
                    CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,2), doc.Total)) AS valorLiquido,
                    dadosBasicos.NumeroCaixa AS numeroEcf,
                    docDestinatario.CpfCnpj AS numeroDocConsumidor,
                    CASE 
                        WHEN docDestinatario.CpfCnpj IS NULL OR LTRIM(RTRIM(docDestinatario.CpfCnpj)) = '' THEN NULL
                        WHEN LEN(docDestinatario.CpfCnpj) > 11 THEN '1'
                        ELSE '0'
                    END AS tipoDocumento,
                    CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,2), COALESCE(doc.AcrescimoSubtotal, 0))) AS valorAcrescimo,
                    CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,2), COALESCE(doc.DescontoSubtotal, 0))) AS valorDesconto,
                    'PDV Metanet' AS nomeCanalVenda,
                    docPDV.CpfPremmiaLoja AS numeroCPFPremmia,
                    docPDV.TransactionIdPremmiaLoja AS idTransacaoPremmia,

                    JSON_QUERY((
                        SELECT
                            itemPDV.CodigoInternoPromocaoBRMania AS codigoInterno,
                            itemPDV.CodigoKitPromocaoBRMania AS codigoKit,
                            itemPDV.TipoPromocaoBRMania AS tipoPromocao,
                            itemPDV.ClassificacaoFiscalNCM AS codigoNcm,
                            itemPDV.CodigoAnp AS codigoAnp,
                            COALESCE(produtoBRMania.CodigoEAN, merc.CodigoBarra) AS codigoEan,
                            setor.CodigoSetor AS codigoSetor,
                            item.NumeroSequencial AS posicao,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), item.Quantidade)) AS quantidade,
                            IIF(doc.Cancelado = 0, 0, item.Cancelado) AS situacao,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), item.ValorUnitario)) AS valorUnitario,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), item.TotalItemSemDesconto)) AS valorBruto,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), COALESCE(de.ValorAlterado, 0))) AS valorDescontoItem,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), COALESCE(ac.ValorAlterado, 0))) AS valorAcrescimo,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), item.TotalItemLiquido)) AS valorLiquido,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), COALESCE(icms.ICMSValor, 0))) AS valorICMS,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), COALESCE(iss.ISSQNValor, 0))) AS valorISS,
                            itemPDV.Descricao AS descricaoProdutoVenda,
                            CONVERT(VARCHAR(10), itemPDV.TipoIntegracao) AS tipoTransacaoPremmia,
                            COALESCE(itemPDV.CodigoExternoPremmiaLoja, itemPDV.IdBeneficioResgatePremmiaLoja) AS idRelacionalPremmia,
                            merc.Id AS codigoArtigoLoja
                        FROM VIEW_FAT_ItemDocumentoFiscalVenda item WITH (NOLOCK)
                        INNER JOIN PDV_ItemDocumentoFiscal itemPDV WITH (NOLOCK)
                            ON itemPDV.Id = item.IdItemCupom
                        INNER JOIN CAD_Mercadoria merc WITH (NOLOCK)
                            ON merc.Id = item.IdMercadoria
                        INNER JOIN CAD_SubGrupoMercadoria subGrupo WITH (NOLOCK)
                            ON merc.IdSubGrupoMercadoria = subGrupo.Id
                        LEFT JOIN FAT_ItemDocumentoFiscalImpostoICMS icms WITH (NOLOCK)
                            ON item.Id = icms.Id
                        LEFT JOIN FAT_ItemDocumentoFiscalImpostoISSQN iss WITH (NOLOCK)
                            ON item.Id = iss.Id
                        LEFT JOIN PDV_AlteracaoValorItemCupom de WITH (NOLOCK)
                            ON itemPDV.Desconto = de.Id
                        LEFT JOIN PDV_AlteracaoValorItemCupom ac WITH (NOLOCK)
                            ON itemPDV.Acrescimo = ac.Id
                        OUTER APPLY
                        (
                            SELECT TOP 1 CodigoEAN
                            FROM [Integracao.BRMania].ProdutoBRMania produtoBRMania WITH (NOLOCK)
                            WHERE merc.Id = produtoBRMania.IdMercadoriaMeta
                        ) produtoBRMania
                        CROSS APPLY
                        (
                            SELECT
                                IIF(dep.Departamento = 0, 'L',
                                    IIF(dep.Departamento = 1, 'P', 'X')) AS CodigoSetor
                            FROM
                            (
                                SELECT CASE
                                    WHEN merc.TipoMercadoria = 1 THEN 1
                                    ELSE COALESCE(merc.DepartamentoBRMania, subGrupo.DepartamentoBRMania)
                                END AS Departamento
                            ) dep
                        ) setor
                        WHERE item.IdDocumentoFiscal = doc.Id
                        FOR JSON PATH
                    )) AS listaItensCupomFiscal,

                    JSON_QUERY((
                        SELECT
                            UPPER(pag.Descricao) AS nomeFormaPagamento,
                            CONVERT(VARCHAR(30), CONVERT(DECIMAL(19,3), pag.ValorPago)) AS valorFormaPagamento
                        FROM PDV_PagamentoDocumentoFiscal pag WITH (NOLOCK)
                        WHERE pag.IdDocumentoFiscal = doc.Id
                        FOR JSON PATH
                    )) AS listaFormaPgtoCupomFiscal

                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )) AS listaCuponsFiscais

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS JsonReconstituido

FROM VIEW_FAT_DocumentoFiscalVendaTodosStatus doc WITH (NOLOCK)
INNER JOIN PDV_DocumentoFiscal docPDV WITH (NOLOCK)
    ON doc.Id = docPDV.Id
INNER JOIN PDV_DadosBasicosDocumento dadosBasicos WITH (NOLOCK)
    ON dadosBasicos.Id = docPDV.InformacoesDocumento
LEFT JOIN FAT_DocumentoFiscalDadosDestinatario docDestinatario WITH (NOLOCK)
    ON docDestinatario.Id = doc.Id
WHERE doc.IdEmpresa = @IdEmpresa
  AND doc.DataMovimentacao >= @DataInicio
  AND doc.DataMovimentacao < DATEADD(DAY, 1, @DataTermino)
  AND doc.Cancelado = 0
  AND docPDV.DataEnvioBRMania IS NOT NULL
ORDER BY doc.DataMovimentacao, doc.Id;
