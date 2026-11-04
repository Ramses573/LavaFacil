-- SOLO LECTURA. Preparado para ejecución manual autorizada; no ejecutado.
USE [LavaFacil];
GO
-- ANTES: confirmar instancia/base/rol; no importar si no es PRINCIPAL.
SELECT @@SERVERNAME AS Instancia, DB_NAME() AS BaseActual,
       mirroring_role_desc AS RolMirroring, mirroring_state_desc AS EstadoMirroring
FROM sys.database_mirroring WHERE database_id = DB_ID();

-- Confirmar esquema desplegado (comparar orden/tipos con los CSV).
SELECT t.name AS Tabla, c.column_id AS Orden, c.name AS Columna,
       TYPE_NAME(c.user_type_id) AS Tipo, c.max_length, c.precision, c.scale,
       c.is_nullable, c.is_identity
FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'dbo'
  AND t.name IN ('Clientes','Servicios','Promociones','Pedidos','Pagos')
ORDER BY t.name, c.column_id;
SELECT OBJECT_NAME(parent_object_id) AS Tabla, name, definition, is_disabled, is_not_trusted
FROM sys.check_constraints
WHERE parent_object_id IN (OBJECT_ID('dbo.Clientes'),OBJECT_ID('dbo.Servicios'),
 OBJECT_ID('dbo.Promociones'),OBJECT_ID('dbo.Pedidos'),OBJECT_ID('dbo.Pagos'));
SELECT OBJECT_NAME(parent_object_id) AS Tabla, name, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE parent_object_id IN (OBJECT_ID('dbo.Clientes'),OBJECT_ID('dbo.Servicios'),
 OBJECT_ID('dbo.Promociones'),OBJECT_ID('dbo.Pedidos'),OBJECT_ID('dbo.Pagos'));
SELECT OBJECT_NAME(parent_id) AS Tabla, name, is_disabled FROM sys.triggers
WHERE parent_id IN (OBJECT_ID('dbo.Pagos'), OBJECT_ID('dbo.DetallePedido'));

-- ANTES deben devolver cero filas; DESPUÉS tres filas por tabla.
SELECT IdCliente,Cedula,Nombre,Apellidos,Telefono,Email,Direccion,FechaRegistro,Activo
FROM dbo.Clientes WHERE IdCliente IN (2001,2002,2003) ORDER BY IdCliente;
SELECT IdServicio,NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,PrecioAdicional,Activo
FROM dbo.Servicios WHERE IdServicio IN (2001,2002,2003) ORDER BY IdServicio;
SELECT IdPromocion,IdServicio,NombrePromocion,Descripcion,PorcentajeDescuento,FechaInicio,FechaFin,Activa
FROM dbo.Promociones WHERE IdPromocion IN (2001,2002,2003) ORDER BY IdPromocion;
SELECT IdPedido,IdCliente,FechaPedido,FechaEntregaEstimada,Estado,Total,Observaciones
FROM dbo.Pedidos WHERE IdPedido IN (2001,2002,2003) ORDER BY IdPedido;
SELECT IdPago,IdPedido,FechaPago,Monto,MetodoPago,EstadoPago,Referencia
FROM dbo.Pagos WHERE IdPago IN (2001,2002,2003) ORDER BY IdPago;

-- ANTES: detectar colisiones de claves únicas de Clientes además de identity.
SELECT IdCliente,Cedula,Email FROM dbo.Clientes
WHERE Cedula IN ('DEMO-P2-C001','DEMO-P2-C002','DEMO-P2-C003')
   OR Email IN ('ana.p2@example.test','luis.p2@example.test','maria.p2@example.test');
SELECT IdServicio,NombreServicio FROM dbo.Servicios
WHERE NombreServicio IN ('Lavado estándar','Lavado de edredón','Lavado de uniformes');

-- DESPUÉS: referencias; las columnas de destino nunca deben ser NULL.
SELECT p.IdPromocion,p.IdServicio,s.IdServicio AS ServicioExistente
FROM dbo.Promociones p LEFT JOIN dbo.Servicios s ON s.IdServicio=p.IdServicio
WHERE p.IdPromocion IN (2001,2002,2003);
SELECT p.IdPedido,p.IdCliente,c.IdCliente AS ClienteExistente
FROM dbo.Pedidos p LEFT JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
WHERE p.IdPedido IN (2001,2002,2003);
SELECT pg.IdPago,pg.IdPedido,p.IdPedido AS PedidoExistente
FROM dbo.Pagos pg LEFT JOIN dbo.Pedidos p ON p.IdPedido=pg.IdPedido
WHERE pg.IdPago IN (2001,2002,2003);

-- ANTES DE PAGOS y DESPUÉS: detalle importado por Ramsés y pagos confirmados.
-- Esperado Total/Detalle: 3600,6500,6000; Pagado tras carga: 3600,6500,0.
SELECT p.IdPedido,p.Total,
 (SELECT SUM(d.Subtotal) FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido) AS TotalDetalle,
 (SELECT COALESCE(SUM(pg.Monto),0) FROM dbo.Pagos pg
  WHERE pg.IdPedido=p.IdPedido AND pg.EstadoPago='Pagado') AS TotalPagado
FROM dbo.Pedidos p WHERE p.IdPedido IN (2001,2002,2003) ORDER BY p.IdPedido;
GO
