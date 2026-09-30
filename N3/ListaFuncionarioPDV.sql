--Função
select * from FN_PegarClientesFuncionarioTelaPesquisa()

-- conferir
SELECT pn.Id, pn.NomeRazao, pn.TipoParceiro, pn.TipoParceiro | 32 AS TipoNovo
FROM ParceiroNegocio pn
INNER JOIN ParceiroNegocioFuncionario f ON f.Id = pn.Id
WHERE pn.Ativo = 1
  AND COALESCE(pn.BloquearCliente, 0) = 0
  AND pn.TipoParceiro & 32 = 0;

-- aplicar (não rode sem confirmar)
UPDATE pn
SET pn.TipoParceiro = pn.TipoParceiro | 32
FROM ParceiroNegocio pn
INNER JOIN ParceiroNegocioFuncionario f ON f.Id = pn.Id
WHERE pn.Ativo = 1
  AND COALESCE(pn.BloquearCliente, 0) = 0
  AND pn.TipoParceiro & 32 = 0;
