-- Datos ficticios persistentes para la entrega. No son la prueba temporal de conmutación.
USE LavaFacil;
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@SERVERNAME<>N'MADRENZO' THROW 50000,'Ejecutar en MADRENZO como principal.',1;
IF NOT EXISTS(SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID() AND mirroring_role_desc='PRINCIPAL' AND mirroring_state_desc='SYNCHRONIZED')
 THROW 50000,'El principal debe estar sincronizado.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @i INT=1,@n VARCHAR(10),@c INT,@e INT,@s INT,@p INT;
 WHILE (SELECT COUNT(*) FROM dbo.Clientes)<3
 BEGIN
  SET @n=CONVERT(VARCHAR(10),@i);
  IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE Cedula='DEMO-CLIENTE-'+@n)
   INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email,Direccion)
   VALUES('DEMO-CLIENTE-'+@n,'Cliente Demo '+@n,'Datos Ficticios','00000000','cliente.demo.'+@n+'@example.test','Direccion ficticia del proyecto '+@n);
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Empleados)<3
 BEGIN
  SET @n=CONVERT(VARCHAR(10),@i);
  IF NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE Cedula='DEMO-EMPLEADO-'+@n)
   INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso)
   VALUES('DEMO-EMPLEADO-'+@n,'Empleado Demo '+@n,'Datos Ficticios','00000000','empleado.demo.'+@n+'@example.test','Empleado','20261011');
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Usuarios)<3
 BEGIN
  SET @n=CONVERT(VARCHAR(10),@i);
  SELECT TOP(1) @c=IdCliente FROM dbo.Clientes ORDER BY IdCliente;
  SELECT TOP(1) @e=IdEmpleado FROM dbo.Empleados WHERE Cedula LIKE 'DEMO-EMPLEADO-%' ORDER BY IdEmpleado;
  IF @e IS NULL SELECT TOP(1) @e=IdEmpleado FROM dbo.Empleados ORDER BY IdEmpleado;
  IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario='demo.entrega.'+@n)
   INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdCliente,IdEmpleado,Activo)
   VALUES('demo.entrega.'+@n,CONVERT(VARCHAR(64),CRYPT_GEN_RANDOM(32),2),CASE WHEN @i%2=1 THEN 'Cliente' ELSE 'Empleado' END,
   CASE WHEN @i%2=1 THEN @c ELSE NULL END,CASE WHEN @i%2=0 THEN @e ELSE NULL END,0);
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Servicios)<3
 BEGIN
  SET @n=CONVERT(VARCHAR(10),@i);
  IF NOT EXISTS(SELECT 1 FROM dbo.Servicios WHERE NombreServicio=CASE @i WHEN 1 THEN 'Lavado, secado y doblado' WHEN 2 THEN 'Uniformes deportivos' ELSE 'Edredones demo '+@n END)
   INSERT dbo.Servicios(NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,PrecioAdicional)
   VALUES(CASE @i WHEN 1 THEN 'Lavado, secado y doblado' WHEN 2 THEN 'Uniformes deportivos' ELSE 'Edredones demo '+@n END,
   'Servicio de demostracion del proyecto',CASE @i WHEN 1 THEN 'Kilogramo' WHEN 2 THEN 'Uniforme' ELSE 'Unidad' END,
   CASE @i WHEN 1 THEN 1500 WHEN 2 THEN 2500 ELSE 6000 END,1,0);
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Pedidos)<3
 BEGIN
  SELECT @c=IdCliente FROM dbo.Clientes ORDER BY IdCliente OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  INSERT dbo.Pedidos(IdCliente,FechaEntregaEstimada,Estado,Observaciones)
  VALUES(@c,'20261015','Pendiente','Pedido ficticio para entrega del proyecto');
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.DetallePedido)<3
 BEGIN
  SELECT @p=IdPedido FROM dbo.Pedidos ORDER BY IdPedido OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  SELECT @s=IdServicio FROM dbo.Servicios ORDER BY IdServicio OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal)
  SELECT @p,@s,1,PrecioBase,0,PrecioBase FROM dbo.Servicios WHERE IdServicio=@s;
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Pagos)<3
 BEGIN
  SELECT @p=IdPedido FROM dbo.Pedidos WHERE Total>0 ORDER BY IdPedido OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  IF @p IS NULL THROW 50000,'Se requieren pedidos con total positivo para datos de pago.',1;
  INSERT dbo.Pagos(IdPedido,Monto,MetodoPago,EstadoPago,Referencia)
  SELECT @p,CASE WHEN Total>=1000 THEN 1000 ELSE Total END,'Efectivo','Pendiente','DEMO-ENTREGA-PAGO-'+CONVERT(VARCHAR(10),@i) FROM dbo.Pedidos WHERE IdPedido=@p;
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Recolecciones)<3
 BEGIN
  SELECT @p=IdPedido FROM dbo.Pedidos ORDER BY IdPedido OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  INSERT dbo.Recolecciones(IdPedido,Direccion,FechaProgramada,Estado,Observaciones)
  VALUES(@p,'Direccion ficticia '+CONVERT(VARCHAR(10),@i),'20261014','Programada','Recoleccion ficticia para entrega');
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Promociones)<3
 BEGIN
  SELECT @s=IdServicio FROM dbo.Servicios ORDER BY IdServicio OFFSET (@i-1)%3 ROWS FETCH NEXT 1 ROW ONLY;
  INSERT dbo.Promociones(IdServicio,NombrePromocion,Descripcion,PorcentajeDescuento,FechaInicio,FechaFin)
  VALUES(@s,'Promocion demo '+CONVERT(VARCHAR(10),@i),'Datos ficticios del proyecto',10,'20261011','20261031');
  SET @i+=1;
 END;
 SET @i=1;
 WHILE (SELECT COUNT(*) FROM dbo.Inventario)<3
 BEGIN
  SET @n=CONVERT(VARCHAR(10),@i);
  IF NOT EXISTS(SELECT 1 FROM dbo.Inventario WHERE NombreProducto=CASE @i WHEN 1 THEN 'Detergente demo' WHEN 2 THEN 'Suavizante demo' ELSE 'Bolsas demo '+@n END)
   INSERT dbo.Inventario(NombreProducto,Descripcion,Cantidad,UnidadMedida,CantidadMinima)
   VALUES(CASE @i WHEN 1 THEN 'Detergente demo' WHEN 2 THEN 'Suavizante demo' ELSE 'Bolsas demo '+@n END,'Datos ficticios del proyecto',10,CASE WHEN @i<=2 THEN 'Litro' ELSE 'Unidad' END,2);
  SET @i+=1;
 END;
 COMMIT TRANSACTION;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT 'Clientes' AS Tabla,COUNT(*) AS Registros FROM dbo.Clientes UNION ALL
SELECT 'Empleados',COUNT(*) FROM dbo.Empleados UNION ALL SELECT 'Usuarios',COUNT(*) FROM dbo.Usuarios UNION ALL
SELECT 'Servicios',COUNT(*) FROM dbo.Servicios UNION ALL SELECT 'Pedidos',COUNT(*) FROM dbo.Pedidos UNION ALL
SELECT 'DetallePedido',COUNT(*) FROM dbo.DetallePedido UNION ALL SELECT 'Pagos',COUNT(*) FROM dbo.Pagos UNION ALL
SELECT 'Recolecciones',COUNT(*) FROM dbo.Recolecciones UNION ALL SELECT 'Promociones',COUNT(*) FROM dbo.Promociones UNION ALL
SELECT 'Inventario',COUNT(*) FROM dbo.Inventario;
