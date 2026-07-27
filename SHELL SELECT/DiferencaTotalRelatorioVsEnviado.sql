DECLARE @DataInicio DATE = '2026-05-25';
DECLARE @DataTermino DATE = '2026-06-24';

WITH Dias AS
(
    SELECT @DataInicio AS DataMovimento
    UNION ALL
    SELECT DATEADD(DAY, 1, DataMovimento)
    FROM Dias
    WHERE DataMovimento < @DataTermino
),
Envio AS
(
    SELECT
        SUM(CONVERT(DECIMAL(18,5), F.Total)) AS TotalEnviado
    FROM Dias D
    OUTER APPLY [Integracao.Raizen].[FN_Venda_PegarDadosEnviarThoth](1, D.DataMovimento) F
),
Rel507 AS
(
    SELECT
        SUM(TotalVenda) AS TotalRelatorio507
    FROM dbo.FN_Relatorio0507VendaMercadoriaShellSelect
    (
        '1',
        @DataInicio,
        @DataTermino,
        '',
        1
    )
)
SELECT
    Envio.TotalEnviado,
    Rel507.TotalRelatorio507,
    Envio.TotalEnviado - Rel507.TotalRelatorio507 AS Diferenca
FROM Envio
CROSS JOIN Rel507
OPTION (MAXRECURSION 0);
