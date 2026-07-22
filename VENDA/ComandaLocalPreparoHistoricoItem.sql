--validar direto no histórico do item SELECT
    item.Id AS IdItemPedido,
    itemConsumo.Id AS IdItemConsumo,
    itemConsumo.Descricao,
    itemConsumo.IdFuncionarioIdentificado,
    itemConsumo.NomeFuncionarioIdentificado,
    realizada.TipoAcao,
    realizada.NomeUsuario,
    realizada.DataHora
FROM ItemPedido item WITH (NOLOCK)
INNER JOIN ItemConsumoRestaurante itemConsumo WITH (NOLOCK)
    ON itemConsumo.Id = item.ItemConsumo
LEFT JOIN AlteracaoItemConsumoRestaurante alteracao WITH (NOLOCK)
    ON alteracao.ItemConsumoRestaurante = itemConsumo.Id
LEFT JOIN ItemAlteracaoRealizadaRegistro realizada WITH (NOLOCK)
    ON realizada.Id = alteracao.ItemAlteracaoRealizadaRegistro
WHERE item.Pedido = @IdPedido
ORDER BY item.Id, realizada.DataHora;
