DECLARE @Versao VARCHAR(255) =
'0983af50-e7e8-11f1-98b8-a9e175a07849';

DECLARE @IdPagamento BIGINT;
DECLARE @ValorPago DECIMAL(19,5);
DECLARE @TotalItens DECIMAL(19,3);
DECLARE @Saldo DECIMAL(19,3);

-- Localiza o pagamento e o valor pago
SELECT
    @IdPagamento = P.Id,
    @ValorPago = P.ValorPago
FROM CargaMovimentacao.PDV_DocumentoFiscalTemp D
INNER JOIN CargaMovimentacao.PDV_PagamentoDocumentoFiscalTemp P
    ON P.IdDocumentoFiscalTemp = D.Id
INNER JOIN CargaMovimentacao.PDV_PagamentoDocumentoFiscalAbasteceAiTemp A
    ON A.IdPagamentoDocumentoFiscal = P.Id
WHERE D.Versao = @Versao;

-- Calcula o total já lançado
SELECT
    @TotalItens = ISNULL(SUM(Valor), 0)
FROM CargaMovimentacao.PDV_ItemPagamentoDocumentoFiscalAbasteceAiTemp
WHERE IdPagamentoAbasteceAiTemp = @IdPagamento;

-- Calcula o saldo
SET @Saldo = ROUND(@ValorPago - @TotalItens, 3);

-- Insere somente se existir saldo positivo
IF @Saldo > 0
BEGIN
    INSERT INTO CargaMovimentacao.PDV_ItemPagamentoDocumentoFiscalAbasteceAiTemp
    (
        IdPagamentoAbasteceAiTemp,
        SubFinalizadora,
        Valor,
        Descricao,
        ValorInformado
    )
    VALUES
    (
        @IdPagamento,
        41,
        @Saldo,
        'SALDO',
        @Saldo
    );

    SELECT 'INSERT REALIZADO' AS Resultado, @Saldo AS ValorInserido;
END
ELSE
BEGIN
    SELECT 'NENHUM INSERT NECESSÁRIO' AS Resultado, @Saldo AS Saldo;
END;
