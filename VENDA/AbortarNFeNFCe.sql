-- Execy
DECLARE @idDoc BIGINT = 0;
UPDATE DocumentoFiscal SET Cancelado = 1, JustificativaCancelamento='ABORTADO VIA BD' WHERE Id = @idDoc;
DELETE FROM DocumentoFiscalAguardando WHERE Id = @idDoc;
UPDATE NotaFiscalEletronica SET Status=4 WHERE Id = @idDoc;
INSERT INTO DocumentoFiscalNaoEnviado values (@idDoc);
