/* 
VALIDACAO - LOCAL DE PREPARO / IMPRESSORA COZINHA

Objetivo:
Validar se a mercadoria está vinculada ao Local de Preparo correto,
qual GUID de impressora será utilizado e se o pedido foi enviado para
a impressora esperada.

Como usar:
1. Ajustar @Gtin com o código de barras da mercadoria.
2. Após venda/teste, ajustar @IdPedido se quiser validar um pedido específico.
*/

DECLARE @Gtin VARCHAR(30) = '00000000003968';
DECLARE @IdPedido BIGINT = NULL; -- preencher se quiser validar pedido específico

-- 1. Locais de preparo cadastrados e impressoras vinculadas
SELECT
    Id,
    Descricao,
    PDV,
    GuidImpressora,
    NomeImpressora,
    PadraoRelatorio,
    Ativo
FROM LocalPreparoCarga
ORDER BY Descricao;

-- 2. PDVs cadastrados no Gerenciador
SELECT
    ECF,
    IpAddress,
    Porta,
    CNPJ,
    IE,
    ProtocoloHttp
FROM InformacoesPDV
ORDER BY ECF;

-- 3. Valida para qual Local de Preparo a mercadoria aponta
SELECT
    merc.Id AS IdMercadoria,
    merc.CodigoBarra AS Gtin,
    merc.Descricao AS Mercadoria,
    cfg.Id AS IdConfiguracao,
    cfg.Descricao AS Configuracao,
    CASE
        WHEN item.Produto = merc.Id THEN 'PRODUTO'
        WHEN item.SubGrupo = sub.Id THEN 'SUBGRUPO'
        WHEN item.Grupo = grp.Id THEN 'GRUPO'
    END AS TipoVinculo,
    local.Id AS IdLocalPreparo,
    local.Descricao AS LocalPreparo,
    local.PDV,
    local.GuidImpressora,
    local.NomeImpressora,
    local.PadraoRelatorio
FROM MercadoriaCarga merc
INNER JOIN SubGrupoMercadoriaCarga sub ON sub.Id = merc.SubGrupoMercadoria
INNER JOIN GrupoMercadoriaCarga grp ON grp.Id = sub.GrupoMercadoria
INNER JOIN ConfiguracaoMercadoriaItemCarga item
    ON item.Produto = merc.Id
    OR item.SubGrupo = sub.Id
    OR item.Grupo = grp.Id
INNER JOIN ConfiguracaoMercadoriaCarga cfg ON cfg.Id = item.ConfiguracaoMercadoria
INNER JOIN LocalPreparoCarga local ON local.Id = cfg.LocalPreparo
WHERE merc.CodigoBarra = @Gtin
  AND cfg.Ativo = 1
  AND local.Ativo = 1
ORDER BY
    CASE
        WHEN item.Produto = merc.Id THEN 1
        WHEN item.SubGrupo = sub.Id THEN 2
        WHEN item.Grupo = grp.Id THEN 3
    END;

-- 4. Pedidos pendentes/visíveis para impressão
SELECT
    p.IdPedido,
    p.Codigo,
    p.Modulo,
    p.Numero,
    p.Quantidade,
    p.DataRealizado,
    p.PDV,
    p.GuidImpressora,
    p.IP,
    p.Porta,
    p.ProtocoloHttp,
    p.Status,
    p.Visualizado,
    p.IdMercadoriaPrioridade,
    p.IdSubGrupoPrioridade,
    p.IdGrupoPrioridade,
    p.IdMercadoria,
    p.TipoImpressao
FROM FN_ObterPedidosParaVisualizacao() p
ORDER BY p.DataRealizado DESC;

-- 5. Últimos pedidos da mercadoria, mesmo que já estejam visualizados/cancelados
SELECT TOP 30
    p.Id AS IdPedido,
    p.Numero,
    p.Status,
    p.Visualizado,
    p.TipoImpressao,
    p.DataRealizado,
    icr.IdentificadorMercadoria,
    m.CodigoBarra AS Gtin,
    icr.Descricao,
    icr.Quantidade,
    c.Tipo AS TipoConsumo,
    c.NumeroMesa,
    c.CodigoContaCliente,
    c.Aberta
FROM Pedido p
INNER JOIN ItemPedido ip ON ip.Pedido = p.Id
INNER JOIN ItemConsumoRestaurante icr ON icr.Id = ip.ItemConsumo
LEFT JOIN MercadoriaCarga m ON m.Id = icr.IdentificadorMercadoria
INNER JOIN ConsumoRestaurante c ON c.Id = icr.ConsumoRestaurante
WHERE m.CodigoBarra = @Gtin
ORDER BY p.DataRealizado DESC;

-- 6. Valida um pedido específico e os itens enviados para a impressora do pedido
IF @IdPedido IS NOT NULL
BEGIN
    SELECT *
    FROM FN_ObterTodosPedidos()
    WHERE IdPedido = @IdPedido
    ORDER BY GuidImpressora;

    SELECT
        pedido.IdPedido,
        pedido.GuidImpressora,
        item.*
    FROM FN_ObterTodosPedidos() pedido
    CROSS APPLY FN_ObterItensPedidoPeloIdPedido(pedido.IdPedido, pedido.GuidImpressora) item
    WHERE pedido.IdPedido = @IdPedido
    ORDER BY pedido.GuidImpressora;
END;
