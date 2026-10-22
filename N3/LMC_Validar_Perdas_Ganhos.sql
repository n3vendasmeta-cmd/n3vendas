/* Diagnostico SOMENTE LEITURA - executar no banco 26850171000101.
   Nao recalcula, nao estorna e nao altera dados.
   Positivo = entrada/ganho; negativo = saida/perda.
   Ajustes de regua sao classificados pelo sistema como variacao de temperatura;
   essa classificacao nao comprova a causa fisica da diferenca.
   Os resultados mostram o estado ATUAL do banco, nao o estado de prints antigos.
*/
DECLARE @Empresa bigint = 21591;       -- POSTO CACIQUE 33
DECLARE @Combustivel bigint = 5046;    -- DIESEL S10 ADITIVADO
DECLARE @Inicio date = '20261001';
DECLARE @Fim date = '20261002';        -- inclusivo

-- 1. Origem por documento/tanque e soma do dia.
-- Mesmo criterio de ajuste usado por FN_PST_ObterReguasLancadasPorTanque.
SELECT
    e.DataMovimentacao AS DataMovimento,
    t.Numero AS Tanque,
    d.Id AS IdDocumento,
    d.Numero AS Documento,
    i.Id AS IdItem,
    e.Id AS IdMovimentoEstoque,
    CASE e.Fluxo WHEN 0 THEN 'Entrada / ganho' ELSE 'Saida / perda' END AS Fluxo,
    e.Quantidade AS Litros,
    CASE e.Fluxo WHEN 0 THEN e.Quantidade ELSE -e.Quantidade END AS PerdaGanhoLitros,
    SUM(CASE e.Fluxo WHEN 0 THEN e.Quantidade ELSE -e.Quantidade END)
        OVER (PARTITION BY CONVERT(date,e.DataMovimentacao)) AS TotalPerdaGanhoDia,
    a.TipoAjusteEstoque, a.MotivoAjuste,
    d.DataRegistro AS RegistroDocumento,
    e.DataRegistro AS RegistroMovimentoEstoque,
    u.Login AS UltimoUsuarioDocumento,
    d.Ativo, d.Status
FROM dbo.EST_EstoqueFisicoAnalitico e
JOIN dbo.PST_Tanque t ON t.Id=e.IdLocalEstoque
JOIN dbo.FAT_ItemDocumentoFiscal i ON i.Id=e.ItemDocumentoOrigem
JOIN dbo.FAT_DocumentoFiscal d ON d.Id=i.IdDocumentoFiscal
JOIN dbo.EST_AjusteEstoque a ON a.Id=d.Id
LEFT JOIN dbo.ACS_Usuario u ON u.Id=d.IdUltimoUsuario
WHERE e.IdEmpresa=@Empresa AND e.IdMercadoria=@Combustivel
  AND e.DataMovimentacao>=@Inicio AND e.DataMovimentacao<DATEADD(day,1,@Fim)
  AND d.TipoDocumento=4 AND a.TipoAjusteEstoque IN (0,3)
ORDER BY e.DataMovimentacao,t.Numero,d.Id;

-- 2. Conciliacao do estoque: saldo atual menos ajustes de regua = saldo sem regua.
-- Essa prova contabil NAO substitui a apuracao independente das vendas do LMC.
-- Permite conferir se o total dos ajustes explica a diferenca vista na tela.
;WITH Ajustes AS (
    SELECT CONVERT(date,e.DataMovimentacao) AS Dia,
           SUM(CASE e.Fluxo WHEN 0 THEN e.Quantidade ELSE -e.Quantidade END) AS Regua
    FROM dbo.EST_EstoqueFisicoAnalitico e
    JOIN dbo.FAT_ItemDocumentoFiscal i ON i.Id=e.ItemDocumentoOrigem
    JOIN dbo.FAT_DocumentoFiscal d ON d.Id=i.IdDocumentoFiscal
    JOIN dbo.EST_AjusteEstoque a ON a.Id=d.Id
    WHERE e.IdEmpresa=@Empresa AND e.IdMercadoria=@Combustivel
      AND e.DataMovimentacao>=@Inicio AND e.DataMovimentacao<DATEADD(day,1,@Fim)
      AND d.TipoDocumento=4 AND a.TipoAjusteEstoque IN (0,3)
    GROUP BY CONVERT(date,e.DataMovimentacao)
), Saldos AS (
    SELECT DataMovimentacao AS Dia,SUM(SaldoTanque) AS Saldo
    FROM dbo.FN_EST_PegarSaldoMercadoriaPorIdComDadosDoTanqueLMC_PorPeriodo(
         CONVERT(varchar(30),@Combustivel),@Inicio,@Fim,@Empresa)
    GROUP BY DataMovimentacao
)
SELECT s.Dia,
       anterior.Saldo AS EstoqueInicial,
       s.Saldo-COALESCE(a.Regua,0) AS SaldoCalculadoSemAjustesReguaDoDia,
       s.Saldo AS EstoqueFechamentoAtual,
       COALESCE(a.Regua,0) AS TotalPerdasGanhosRegua,
       'Conferir este total com Perdas e Ganhos da tela atualizada' AS Validacao
FROM Saldos s
LEFT JOIN Saldos anterior ON anterior.Dia=DATEADD(day,-1,s.Dia)
LEFT JOIN Ajustes a ON a.Dia=s.Dia
WHERE s.Dia BETWEEN @Inicio AND @Fim
ORDER BY s.Dia;

-- 3. Valores informados no lancamento de regua e saldo atual de cada tanque.
-- Divergencia pode ocorrer por movimentacoes posteriores/retroativas.
-- Historico pode conter mais de um lancamento por tanque/dia: nao somar cegamente.
SELECT h.Id AS IdHistorico, h.DataMovimento, t.Numero AS Tanque,
       h.DataRegistro, h.ValorLancamento AS VolumeInformadoRegua,
       h.ValorEstornado,
       s.SaldoTanque AS SaldoAtualTanque,
       s.SaldoTanque-h.ValorLancamento AS DiferencaSaldoAtualParaVolumeInformado
FROM dbo.EST_HistoricoLancamentoDiarioRegua h
JOIN dbo.PST_Tanque t ON t.Id=h.IdTanque
LEFT JOIN dbo.FN_EST_PegarSaldoMercadoriaPorIdComDadosDoTanqueLMC_PorPeriodo(
     CONVERT(varchar(30),@Combustivel),@Inicio,@Fim,@Empresa) s
     ON s.IdTanque=h.IdTanque AND s.DataMovimentacao=h.DataMovimento
WHERE t.IdEmpresa=@Empresa AND h.IdCombustivel=@Combustivel
  AND h.DataMovimento BETWEEN @Inicio AND @Fim
ORDER BY h.DataMovimento,t.Numero,h.DataRegistro;
