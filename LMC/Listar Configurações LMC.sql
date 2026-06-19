DECLARE @IdEmpresa BIGINT = 1;

SELECT
    Id,
    IdEmpresa,
    ExibeDetalhesVendaDiaObservacao,
    UtilizarValorVendaDocumentoFiscal,
    DefinirNumeroCasasDecimaisEncerrante,
    QuantidadeCasasDecimaisEncerrante,
    ToleranciaEntreEncerrantes,
    DefinirToleranciaEntreEncerrantes,
    CalcularVendaDiaPeloEncerrante,
    RealizaLeituraTanques,
    TipoLancamentoMedicaoTanque,
    TipoLancamentoNFePerda,
    ObrigatorioNFePerda,
    DesabilitaLancamentoContabilRegua
FROM CFG_ConfiguracoesLivroMovimentacaoCombustivel
WHERE IdEmpresa = @IdEmpresa;
