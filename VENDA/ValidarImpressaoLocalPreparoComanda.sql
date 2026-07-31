-- Valida os locais de preparo carregados no GerenciadorPDV
-- Regra:
-- COZINHA deve ter o GuidImpressora igual ao GUID da impressora secundária COZINHA no XML do PDV.
-- PDV/BALCAO deve ter o GuidImpressora igual ao GUID da impressora secundária PDV/BALCAO no XML.
-- Se o GUID estiver diferente do XML, o pedido pode ser direcionado para impressora errada.

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

--Validar Para Onde o Pedido Foi Direcionado
DECLARE @IdPedido BIGINT = 82; -- informe o pedido novo

SELECT
    IdPedido,
    Codigo,
    Modulo,
    Numero,
    Quantidade,
    DataRealizado,
    PDV,
    GuidImpressora,
    IP,
    Porta,
    ProtocoloHttp,
    Status,
    Visualizado,
    IdMercadoriaPrioridade,
    IdSubGrupoPrioridade,
    IdGrupoPrioridade,
    IdMercadoria,
    TipoImpressao,
    CASE TipoImpressao
        WHEN 0 THEN 'NOVO PEDIDO'
        WHEN 1 THEN 'ITEM CANCELADO'
        WHEN 2 THEN 'PEDIDO CANCELADO'
        ELSE 'DESCONHECIDO'
    END AS DescricaoTipoImpressao
FROM FN_ObterPedidosParaVisualizacao()
WHERE IdPedido = @IdPedido;

--Validar Se o Item Retorna Somente Para a Cozinha
DECLARE @IdPedido BIGINT = 82; -- informe o pedido novo

DECLARE @GuidCozinha VARCHAR(50);
DECLARE @GuidPDV VARCHAR(50);

SELECT @GuidCozinha = GuidImpressora
FROM LocalPreparoCarga
WHERE Descricao = 'COZINHA';

SELECT @GuidPDV = GuidImpressora
FROM LocalPreparoCarga
WHERE Descricao = 'PDV';

-- Deve retornar o item se ele estiver configurado para COZINHA
SELECT
    'ITENS PARA COZINHA' AS Validacao,
    *
FROM FN_ObterItensPedidoPeloIdPedido(@IdPedido, @GuidCozinha);

-- Não deve retornar item se ele não estiver configurado para PDV
SELECT
    'ITENS PARA PDV' AS Validacao,
    *
FROM FN_ObterItensPedidoPeloIdPedido(@IdPedido, @GuidPDV);

--Comandos PowerShell Para Validar Impressoras do Windows
Get-Printer -Name "IT-110 COZINHA","IT-110 PDV" |
Select-Object Name, DriverName, PortName, Shared, ShareName, Published, PrinterStatus, JobCount

Get-PrinterPort -Name "192.168.123.100","USB003" |
Select-Object Name, PrinterHostAddress, PortNumber, Protocol, Description

--Limpar e Ativar Log de Impressão do Windows
wevtutil cl Microsoft-Windows-PrintService/Operational
wevtutil sl Microsoft-Windows-PrintService/Operational /e:true

--Depois faça o teste no sistema e rode:
Get-WinEvent -LogName Microsoft-Windows-PrintService/Operational -MaxEvents 50 |
Where-Object {
    $_.Message -like "*IT-110*" -or
    $_.Message -like "*COZINHA*" -or
    $_.Message -like "*pdv*"
} |
Select-Object TimeCreated, Id, Message |
Format-List
