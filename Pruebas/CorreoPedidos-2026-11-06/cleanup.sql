SET XACT_ABORT ON; BEGIN TRAN;
DECLARE @U TABLE(IdUsuario int); DECLARE @C TABLE(IdCliente int); DECLARE @P TABLE(IdPedido int);
INSERT @U SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario LIKE 'autopedido%' OR NombreUsuario LIKE 'autotest.cookie%';
INSERT @C SELECT IdCliente FROM dbo.Clientes WHERE Email LIKE 'autopedido%@example.com' OR Email LIKE 'autotest.cookie%@example.com';
INSERT @P SELECT IdPedido FROM dbo.Pedidos WHERE IdCliente IN (SELECT IdCliente FROM @C);
DELETE FROM dbo.CorreoEnvios WHERE IdPedido IN (SELECT IdPedido FROM @P) OR Destino LIKE 'autopedido%@example.com' OR Destino LIKE 'autotest.cookie%@example.com';
DELETE FROM dbo.Pagos WHERE IdPedido IN (SELECT IdPedido FROM @P);
DELETE FROM dbo.DetallePedido WHERE IdPedido IN (SELECT IdPedido FROM @P);
DELETE FROM dbo.Recolecciones WHERE IdPedido IN (SELECT IdPedido FROM @P);
DELETE FROM dbo.Pedidos WHERE IdPedido IN (SELECT IdPedido FROM @P);
DELETE FROM dbo.TokensCorreo WHERE IdUsuario IN (SELECT IdUsuario FROM @U);
DELETE FROM dbo.PerfilesApp WHERE IdUsuario IN (SELECT IdUsuario FROM @U);
DELETE FROM dbo.Usuarios WHERE IdUsuario IN (SELECT IdUsuario FROM @U);
DELETE FROM dbo.Clientes WHERE IdCliente IN (SELECT IdCliente FROM @C);
COMMIT;
SELECT (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario LIKE 'autopedido%' OR NombreUsuario LIKE 'autotest.cookie%') Usuarios,
       (SELECT COUNT(*) FROM dbo.Clientes WHERE Email LIKE 'autopedido%@example.com' OR Email LIKE 'autotest.cookie%@example.com') Clientes,
       (SELECT COUNT(*) FROM dbo.Pedidos WHERE IdCliente NOT IN (SELECT IdCliente FROM dbo.Clientes)) PedidosHuerfanos,
       (SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE Destino LIKE 'autopedido%@example.com' OR Destino LIKE 'autotest.cookie%@example.com') CorreoEnvios;