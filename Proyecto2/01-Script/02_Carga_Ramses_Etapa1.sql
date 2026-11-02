USE [LavaFacil];
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (
    SELECT 1 FROM dbo.Empleados
    WHERE IdEmpleado BETWEEN 2001 AND 2003
)
    THROW 50001, 'Los IDs 2001-2003 de Empleados ya existen. No se realizó la carga.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.Inventario
    WHERE IdInventario BETWEEN 2001 AND 2003
)
    THROW 50002, 'Los IDs 2001-2003 de Inventario ya existen. No se realizó la carga.', 1;

SET IDENTITY_INSERT dbo.Empleados ON;

INSERT INTO dbo.Empleados
    (IdEmpleado, Cedula, Nombre, Apellidos, Telefono, Email, Cargo, FechaIngreso, Activo)
VALUES
    (2001, 'DEMO-P2-E001', 'Carlos', N'Jiménez Soto', '71000001', 'carlos.p2@example.test', 'Empleado', '2026-10-24', 1),
    (2002, 'DEMO-P2-E002', N'Sofía', N'Mora López', '71000002', 'sofia.p2@example.test', 'Empleado', '2026-10-24', 1),
    (2003, 'DEMO-P2-E003', 'Daniel', 'Rojas Vega', '71000003', 'daniel.p2@example.test', 'Administrador', '2026-10-24', 1);

SET IDENTITY_INSERT dbo.Empleados OFF;

SET IDENTITY_INSERT dbo.Inventario ON;

INSERT INTO dbo.Inventario
    (IdInventario, NombreProducto, Descripcion, Cantidad, UnidadMedida, CantidadMinima, FechaActualizacion, Activo)
VALUES
    (2001, N'Detergente líquido', 'Detergente concentrado', 25.00, 'Litro', 5.00, '2026-10-24T10:00:00', 1),
    (2002, 'Suavizante', 'Suavizante floral', 18.00, 'Litro', 4.00, '2026-10-24T10:00:00', 1),
    (2003, 'Bolsas transparentes', 'Bolsas para entrega', 150.00, 'Unidad', 30.00, '2026-10-24T10:00:00', 1);

SET IDENTITY_INSERT dbo.Inventario OFF;

COMMIT TRANSACTION;
GO

SELECT *
FROM dbo.Empleados
WHERE IdEmpleado BETWEEN 2001 AND 2003
ORDER BY IdEmpleado;

SELECT *
FROM dbo.Inventario
WHERE IdInventario BETWEEN 2001 AND 2003
ORDER BY IdInventario;
GO
