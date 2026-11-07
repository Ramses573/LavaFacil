SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @tag varchar(80)='QA-DIRECTO-'+CONVERT(varchar(36),NEWID());
DECLARE @cedula varchar(20)=LEFT(@tag,20), @mail varchar(150)=@tag+'@example.test', @refAnulado varchar(100)=@tag+'-ANULADO';
DECLARE @user varchar(50)=LEFT(REPLACE(@tag,'-',''),50), @clave varchar(255)='Temporal-QA-2026';
DECLARE @emp int,@usr int,@cli int,@svc int,@pedido int,@pago int,@pagoAnulado int,@envio bigint;
DECLARE @tokenA uniqueidentifier,@tokenB uniqueidentifier,@bad uniqueidentifier=NEWID(),@ok bit,@err varchar(1000);
DECLARE @fecha date=CONVERT(date,GETDATE()), @entrega datetime=DATEADD(day,1,GETDATE());
DECLARE @checks table(CheckName varchar(80),Estado varchar(10),Detalle varchar(max));
BEGIN TRY
  EXEC dbo.InsertarEmpleado @Cedula=@cedula,@Nombre='QA',@Apellidos='Directo',@Telefono='5550000000',@Email=@mail,@Cargo='Administrador',@FechaIngreso=@fecha;
  SELECT @emp=IdEmpleado FROM dbo.Empleados WHERE Cedula=@cedula;
  EXEC dbo.InsertarUsuario @NombreUsuario=@user,@Clave=@clave,@TipoUsuario='Administrador',@IdCliente=NULL,@IdEmpleado=@emp;
  SELECT @usr=IdUsuario FROM dbo.Usuarios WHERE NombreUsuario=@user;
  EXEC dbo.InsertarCliente @Cedula=@cedula,@Nombre='QA',@Apellidos='Cliente',@Telefono='5550000001',@Email=@mail,@Direccion='Temporal';
  SELECT @cli=IdCliente FROM dbo.Clientes WHERE Cedula=@cedula;
  EXEC dbo.InsertarServicio @NombreServicio=@tag,@Descripcion='Fixture temporal',@TipoCobro='Kilogramo',@PrecioBase=100,@CantidadIncluida=1,@PrecioAdicional=0;
  SELECT @svc=IdServicio FROM dbo.Servicios WHERE NombreServicio=@tag;
  EXEC dbo.InsertarPedido @IdCliente=@cli,@FechaEntregaEstimada=@entrega,@Estado='Pendiente',@Total=100,@Observaciones=@tag;
  SELECT @pedido=IdPedido FROM dbo.Pedidos WHERE Observaciones=@tag;
  EXEC dbo.InsertarDetallePedido @IdPedido=@pedido,@IdServicio=@svc,@Cantidad=1,@PrecioBase=100,@MontoAdicional=0,@Subtotal=100;
  EXEC dbo.InsertarPago @IdPedido=@pedido,@Monto=100,@MetodoPago='Efectivo',@EstadoPago='Pendiente',@Referencia=@tag;
  SELECT @pago=IdPago FROM dbo.Pagos WHERE Referencia=@tag;
  INSERT dbo.Pagos(IdPedido,Monto,MetodoPago,EstadoPago,Referencia) VALUES(@pedido,100,'Efectivo','Anulado',@refAnulado);
  SET @pagoAnulado=SCOPE_IDENTITY();
  UPDATE dbo.Pedidos SET Total=(SELECT SUM(Subtotal) FROM dbo.DetallePedido WHERE IdPedido=@pedido) WHERE IdPedido=@pedido;
  INSERT @checks SELECT 'fixture IDs',CASE WHEN @emp>0 AND @usr>0 AND @cli>0 AND @svc>0 AND @pedido>0 AND @pago>0 AND @pagoAnulado>0 THEN 'PASS' ELSE 'FAIL' END,CONCAT('IdUsuario=',@usr,' IdPedido=',@pedido,' IdPago=',@pago,' IdPagoAnulado=',@pagoAnulado);

  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pago,@pedido,100,'Efectivo','Pagado',@tag; INSERT @checks VALUES('Pendiente a Pagado','PASS','sin error'); END TRY BEGIN CATCH INSERT @checks VALUES('Pendiente a Pagado','FAIL',CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  INSERT @checks SELECT 'CorreoEnvios único',CASE WHEN (SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE IdPago=@pago AND Tipo='ComprobantePago')=1 THEN 'PASS' ELSE 'FAIL' END,CONCAT('count=',(SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE IdPago=@pago AND Tipo='ComprobantePago'));
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pago,@pedido,100,'Efectivo','Pagado',@tag; INSERT @checks SELECT 'repetir Pagado','PASS',CONCAT('count=',(SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE IdPago=@pago AND Tipo='ComprobantePago')); END TRY BEGIN CATCH INSERT @checks VALUES('repetir Pagado','FAIL',CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pago,@pedido,100.01,'Efectivo','Pagado',@tag; INSERT @checks VALUES('monto superior','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks VALUES('monto superior',CASE WHEN ERROR_NUMBER()=50101 THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pago,@pedido,100,'Efectivo','Pendiente',@tag; INSERT @checks VALUES('Pagado a Pendiente','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks VALUES('Pagado a Pendiente',CASE WHEN ERROR_NUMBER()=50101 THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pago,@pedido,100,'Efectivo','Anulado',@tag; INSERT @checks VALUES('Pagado a Anulado','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks VALUES('Pagado a Anulado',CASE WHEN ERROR_NUMBER()=50101 THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pagoAnulado,@pedido,100,'Efectivo','Pagado',@refAnulado; INSERT @checks VALUES('Anulado a Pagado','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks VALUES('Anulado a Pagado',CASE WHEN ERROR_NUMBER()=50101 THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  BEGIN TRY EXEC dbo.app_ActualizarPagoSeguro @usr,@pagoAnulado,@pedido,100,'Efectivo','Pendiente',@refAnulado; INSERT @checks VALUES('Anulado a Pendiente','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks VALUES('Anulado a Pendiente',CASE WHEN ERROR_NUMBER()=50101 THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
  INSERT @checks SELECT 'Pedido total y DatosJson',CASE WHEN p.Total<>0 AND EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdPago=@pago AND NULLIF(DatosJson,'') IS NOT NULL AND DATALENGTH(DatosJson)>2) THEN 'PASS' ELSE 'FAIL' END,CONCAT('Total=',p.Total,' DatosJsonBytes=',COALESCE((SELECT MAX(DATALENGTH(DatosJson)) FROM dbo.CorreoEnvios WHERE IdPago=@pago),0)) FROM dbo.Pedidos p WHERE p.IdPedido=@pedido;

  INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,Destino,Asunto,DatosJson,Estado,Intentos,ProximoIntento,CreadoEn) VALUES('QADirecto',@tag+'-LEASE','qa@example.test','QA','{"fixture":true}','Pendiente',0,DATEADD(year,-1,SYSUTCDATETIME()),SYSUTCDATETIME());
  SET @envio=SCOPE_IDENTITY();
  DECLARE @c table(IdEnvio bigint,Tipo varchar(100),ClaveUnica varchar(200),IdPedido int,IdPago int,Destino varchar(500),Asunto varchar(500),DatosJson nvarchar(max),Estado varchar(50),Intentos int,ProximoIntento datetime2,TokenLease uniqueidentifier,ProcesandoHasta datetime2,CreadoEn datetime2,EnviadoEn datetime2,UltimoError varchar(1000));
  INSERT @c EXEC dbo.app_ReclamarCorreo 1; SELECT @tokenA=TokenLease FROM @c WHERE IdEnvio=@envio;
  INSERT @checks SELECT 'lease token A',CASE WHEN @tokenA IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@envio AND Estado='Procesando' AND TokenLease=@tokenA) THEN 'PASS' ELSE 'FAIL' END,CONCAT('tokenA=',@tokenA);
  BEGIN TRY EXEC dbo.app_ResolverCorreo @envio,@bad,1,NULL; INSERT @checks VALUES('lease token incorrecto','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks SELECT 'lease token incorrecto',CASE WHEN ERROR_NUMBER()=50104 AND EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@envio AND Estado='Procesando' AND TokenLease=@tokenA) THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE()); END CATCH;
  UPDATE dbo.CorreoEnvios SET ProcesandoHasta=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE IdEnvio=@envio;
  DELETE FROM @c; INSERT @c EXEC dbo.app_ReclamarCorreo 1; SELECT @tokenB=TokenLease FROM @c WHERE IdEnvio=@envio;
  INSERT @checks SELECT 'lease token B distinto',CASE WHEN @tokenA IS NOT NULL AND @tokenB IS NOT NULL AND @tokenA<>@tokenB THEN 'PASS' ELSE 'FAIL' END,CONCAT('tokenA=',@tokenA,' tokenB=',@tokenB);
  BEGIN TRY EXEC dbo.app_ResolverCorreo @envio,@tokenA,1,NULL; INSERT @checks VALUES('token A vencido','FAIL','no lanzó error'); END TRY BEGIN CATCH INSERT @checks SELECT 'token A vencido',CASE WHEN ERROR_NUMBER()=50104 AND EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@envio AND Estado='Procesando' AND TokenLease=@tokenB) THEN 'PASS' ELSE 'FAIL' END,CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE()); END CATCH;
  BEGIN TRY EXEC dbo.app_ResolverCorreo @envio,@tokenB,1,NULL; INSERT @checks SELECT 'token B resuelve Enviado',CASE WHEN EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@envio AND Estado='Enviado' AND TokenLease IS NULL) THEN 'PASS' ELSE 'FAIL' END,'Estado Enviado'; END TRY BEGIN CATCH INSERT @checks VALUES('token B resuelve Enviado','FAIL',CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;
END TRY
BEGIN CATCH INSERT @checks VALUES('error de fixture','FAIL',CONCAT(ERROR_NUMBER(),': ',ERROR_MESSAGE())); END CATCH;

SELECT CheckName,Estado,Detalle,@usr IdUsuario,@pedido IdPedido,@pago IdPago,@pagoAnulado IdPagoAnulado,@envio IdEnvio FROM @checks ORDER BY CASE WHEN Estado='FAIL' THEN 0 ELSE 1 END,CheckName;
-- Limpieza absoluta de los identificadores temporales, incluida la cola de lease.
DELETE FROM dbo.CorreoEnvios WHERE IdPago IN (@pago,@pagoAnulado) OR IdPedido=@pedido OR ClaveUnica LIKE @tag+'%';
DELETE FROM dbo.Pagos WHERE IdPago IN (@pago,@pagoAnulado) OR Referencia LIKE @tag+'%';
DELETE FROM dbo.DetallePedido WHERE IdPedido=@pedido;
DELETE FROM dbo.Pedidos WHERE IdPedido=@pedido;
DELETE FROM dbo.Servicios WHERE IdServicio=@svc;
DELETE FROM dbo.Clientes WHERE IdCliente=@cli;
DELETE FROM dbo.TokensCorreo WHERE IdUsuario=@usr;
DELETE FROM dbo.PerfilesApp WHERE IdUsuario=@usr;
DELETE FROM dbo.Usuarios WHERE IdUsuario=@usr;
DELETE FROM dbo.Empleados WHERE IdEmpleado=@emp;
SELECT 'CLEANUP' CheckName,CASE WHEN NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@emp) AND NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@usr) AND NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@cli) AND NOT EXISTS(SELECT 1 FROM dbo.Pedidos WHERE IdPedido=@pedido) AND NOT EXISTS(SELECT 1 FROM dbo.Pagos WHERE IdPago IN(@pago,@pagoAnulado)) AND NOT EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdPago IN(@pago,@pagoAnulado) OR ClaveUnica LIKE @tag+'%') THEN 'PASS' ELSE 'FAIL' END Estado;
