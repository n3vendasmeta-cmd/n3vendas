-- Cria uma cópia completa da tabela original com os registros filtrados
SELECT *
INTO CargaMovimentacao.PDV_RestauranteDocumentoFiscalTempBK
FROM CargaMovimentacao.PDV_RestauranteDocumentoFiscalTemp
WHERE IdDocumentoFiscalTemp IN 
(

);
