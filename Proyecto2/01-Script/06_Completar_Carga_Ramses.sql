USE [LavaFacil];
GO

SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Inventario WHERE IdInventario BETWEEN 2001 AND 2003)
BEGIN
    SET IDENTITY_INSERT dbo.Inventario ON;
    INSERT INTO dbo.Inventario
        (IdInventario, NombreProducto, Descripcion, Cantidad, UnidadMedida, CantidadMinima, FechaActualizacion, Activo)
    VALUES
        (2001, N'Detergente líquido', N'Detergente concentrado', 25.00, N'Litro', 5.00, '2026-10-24T10:00:00', 1),
        (2002, N'Suavizante', N'Suavizante floral', 18.00, N'Litro', 4.00, '2026-10-24T10:00:00', 1),
        (2003, N'Bolsas transparentes', N'Bolsas para entrega', 150.00, N'Unidad', 30.00, '2026-10-24T10:00:00', 1);
    SET IDENTITY_INSERT dbo.Inventario OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IdUsuario BETWEEN 2001 AND 2003)
BEGIN
    SET IDENTITY_INSERT dbo.Usuarios ON;
    INSERT INTO dbo.Usuarios
        (IdUsuario, NombreUsuario, Clave, TipoUsuario, IdCliente, IdEmpleado, Activo, FechaCreacion)
    VALUES
        (2001, N'cliente_p2_01',  N'DemoTemporal2026!1', N'Cliente',       2001, NULL, 0, '2026-10-24T10:10:00'),
        (2002, N'empleado_p2_01', N'DemoTemporal2026!2', N'Empleado',      NULL, 2001, 0, '2026-10-24T10:10:00'),
        (2003, N'admin_p2_01',     N'DemoTemporal2026!3', N'Administrador', NULL, 2003, 0, '2026-10-24T10:10:00');
    SET IDENTITY_INSERT dbo.Usuarios OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Recolecciones WHERE IdRecoleccion BETWEEN 2001 AND 2003)
BEGIN
    SET IDENTITY_INSERT dbo.Recolecciones ON;
    INSERT INTO dbo.Recolecciones
        (IdRecoleccion, IdPedido, Direccion, FechaProgramada, Estado, Observaciones)
    VALUES
        (2001, 2001, N'Turrialba centro',     '2026-10-24T11:00:00', N'Programada',  N'Dato de prueba Proyecto 2'),
        (2002, 2002, N'La Suiza Turrialba',   '2026-10-24T11:30:00', N'Recolectada', N'Dato de prueba Proyecto 2'),
        (2003, 2003, N'Santa Cruz Turrialba', '2026-10-24T12:00:00', N'Cancelada',   N'Dato de prueba Proyecto 2');
    SET IDENTITY_INSERT dbo.Recolecciones OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.DetallePedido WHERE IdDetalle BETWEEN 2001 AND 2003)
BEGIN
    SET IDENTITY_INSERT dbo.DetallePedido ON;
    INSERT INTO dbo.DetallePedido
        (IdDetalle, IdPedido, IdServicio, Cantidad, PrecioBase, MontoAdicional, Subtotal)
    VALUES
        (2001, 2001, 2001, 2.00, 1800.00, 0.00, 3600.00),
        (2002, 2002, 2002, 1.00, 6500.00, 0.00, 6500.00),
        (2003, 2003, 2003, 2.00, 3000.00, 0.00, 6000.00);
    SET IDENTITY_INSERT dbo.DetallePedido OFF;
END;
GO

SELECT N'Empleados' AS Tabla, COUNT(*) AS Registros FROM dbo.Empleados WHERE IdEmpleado BETWEEN 2001 AND 2003
UNION ALL SELECT N'Inventario', COUNT(*) FROM dbo.Inventario WHERE IdInventario BETWEEN 2001 AND 2003
UNION ALL SELECT N'Usuarios', COUNT(*) FROM dbo.Usuarios WHERE IdUsuario BETWEEN 2001 AND 2003
UNION ALL SELECT N'Recolecciones', COUNT(*) FROM dbo.Recolecciones WHERE IdRecoleccion BETWEEN 2001 AND 2003
UNION ALL SELECT N'DetallePedido', COUNT(*) FROM dbo.DetallePedido WHERE IdDetalle BETWEEN 2001 AND 2003;
GO
