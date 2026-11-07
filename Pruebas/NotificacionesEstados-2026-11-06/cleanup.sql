SET NOCOUNT ON;
DECLARE @tag varchar(80)='$(pTag)';
DECLARE @pedido int=(SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones=@tag);
DECLARE @cli int=(SELECT IdCliente FROM dbo.Clientes WHERE Cedula=LEFT(REPLACE(@tag,'-',''),19)+'C');
DECLARE @emp int=(SELECT IdEmpleado FROM dbo.Empleados WHERE Cedula=LEFT(REPLACE(@tag,'-',''),20));
DECLARE @admin int=(SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$(pAdminUser)');
DECLARE @client int=(SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$(pClientUser)');
DECLARE @noemail int=(SELECT IdCliente FROM dbo.Clientes WHERE Cedula=LEFT(REPLACE(@tag,'-',''),18)+'N');
DELETE FROM dbo.CorreoEnvios WHERE IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE @tag+'%') OR Destino=@tag+'@example.test';
DELETE FROM dbo.DetallePedido WHERE IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE @tag+'%');
DELETE FROM dbo.Pedidos WHERE Observaciones LIKE @tag+'%';
DELETE FROM dbo.Servicios WHERE NombreServicio='Lavado <script>alert(1)</script>';
DELETE FROM dbo.TokensCorreo WHERE IdUsuario IN (@admin,@client);
DELETE FROM dbo.PerfilesApp WHERE IdUsuario IN (@admin,@client);
DELETE FROM dbo.Usuarios WHERE IdUsuario IN (@admin,@client);
DELETE FROM dbo.Clientes WHERE IdCliente=@cli;
DELETE FROM dbo.Clientes WHERE IdCliente=@noemail;
DELETE FROM dbo.Empleados WHERE IdEmpleado=@emp;
SELECT 'cleanup',
 (SELECT COUNT(*) FROM dbo.Usuarios WHERE IdUsuario IN (@admin,@client)),
 (SELECT COUNT(*) FROM dbo.Empleados WHERE IdEmpleado=@emp),
 (SELECT COUNT(*) FROM dbo.Clientes WHERE IdCliente=@cli),
 (SELECT COUNT(*) FROM dbo.Pedidos WHERE Observaciones LIKE @tag+'%'),
 (SELECT COUNT(*) FROM dbo.DetallePedido WHERE IdPedido=@pedido),
 (SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE IdPedido=@pedido);
