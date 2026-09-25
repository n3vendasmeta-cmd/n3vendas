-- 1) ARLA = subgrupo 4
SELECT
    '1) ARLA = subgrupo 4' AS Consulta,
    Id,
    Descricao,
    SubGrupoMercadoria
FROM Mercadoria
WHERE Descricao LIKE '%ARLA 32 GRANEL%';

-- 2) Regras de Comissão por Meta que pegam o subgrupo 4
SELECT DISTINCT
    '2) Regras Meta do subgrupo 4' AS Consulta,
    Descricao,
    Tipo,
    IdSubgrupo,
    IdParceiroNegocio,
    Ativo,
    Status
FROM ComissaoPorMeta
WHERE Ativo = 1 AND Status = 0 AND Tipo = 2
  AND (',' + IdSubgrupo + ',') LIKE '%,4,%';

-- 3) Quem essa regra joga no combo (tem que ser 7)
SELECT DISTINCT
    '3) Combo da ARLA (Comissao por Meta)' AS Consulta,
    pn.Id,
    pn.NomeRazao
FROM ComissaoPorMeta c
CROSS APPLY dbo.FN_SIS_ArrayVarchar(c.IdParceiroNegocio) p
INNER JOIN ParceiroNegocio pn ON pn.Id = TRY_CAST(p.number AS BIGINT)
WHERE c.Ativo = 1 AND c.Status = 0 AND c.Tipo = 2
  AND (',' + c.IdSubgrupo + ',') LIKE '%,4,%'
ORDER BY pn.NomeRazao;

-- 4) Todos os funcionários (tem que ser 17)
SELECT
    '4) Todos os funcionarios' AS Consulta,
    COUNT(*) AS Qtd,
    Id,
    NomeRazao
FROM dbo.FN_PegarClientesFuncionarioTelaPesquisa()
GROUP BY Id, NomeRazao
ORDER BY NomeRazao;
