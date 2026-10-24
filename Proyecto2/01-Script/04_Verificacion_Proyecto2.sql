USE [LavaFacil];
GO

SELECT t.name AS Tabla, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
WHERE t.name IN (N'Clientes',N'Empleados',N'Usuarios',N'Servicios',N'Pedidos',N'DetallePedido',N'Pagos',N'Recolecciones',N'Promociones',N'Inventario')
GROUP BY t.name
ORDER BY t.name;

SELECT name AS Procedimiento
FROM sys.procedures
WHERE name LIKE N'Insertar%' OR name LIKE N'Actualizar%' OR name LIKE N'Eliminar%' OR name LIKE N'Consultar%' OR name=N'usp_ValidarLogin'
ORDER BY name;

SELECT name AS TriggerNombre, OBJECT_NAME(parent_id) AS Tabla
FROM sys.triggers
WHERE parent_class_desc=N'OBJECT_OR_COLUMN'
ORDER BY Tabla, TriggerNombre;
GO
