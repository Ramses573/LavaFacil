USE [LavaFacil];
GO

SET XACT_ABORT ON;

IF (SELECT COUNT(*) FROM dbo.Pedidos WHERE IdPedido BETWEEN 2001 AND 2003) <> 3
    THROW 50201, 'Faltan los Pedidos 2001-2003 requeridos por Recolecciones y DetallePedido.', 1;

IF (SELECT COUNT(*) FROM dbo.Servicios WHERE IdServicio BETWEEN 2001 AND 2003) <> 3
    THROW 50202, 'Faltan los Servicios 2001-2003 requeridos por DetallePedido.', 1;

IF EXISTS (SELECT 1 FROM dbo.Recolecciones WHERE IdRecoleccion BETWEEN 2001 AND 2003)
    THROW 50203, 'Las Recolecciones 2001-2003 ya existen. No se realizó la carga.', 1;

IF EXISTS (SELECT 1 FROM dbo.DetallePedido WHERE IdDetalle BETWEEN 2001 AND 2003)
    THROW 50204, 'Los Detalles 2001-2003 ya existen. No se realizó la carga.', 1;

BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.Recolecciones ON;

INSERT INTO dbo.Recolecciones
    (IdRecoleccion, IdPedido, Direccion, FechaProgramada, Estado, Observaciones)
VALUES
    (2001, 2001, 'Turrialba centro',     '2026-10-24T11:00:00', 'Programada', 'Dato de prueba Proyecto 2'),
    (2002, 2002, 'La Suiza Turrialba',   '2026-10-24T11:30:00', 'En camino',  'Dato de prueba Proyecto 2'),
    (2003, 2003, 'Santa Cruz Turrialba', '2026-10-24T12:00:00', 'Completada', 'Dato de prueba Proyecto 2');

SET IDENTITY_INSERT dbo.Recolecciones OFF;

SET IDENTITY_INSERT dbo.DetallePedido ON;

INSERT INTO dbo.DetallePedido
    (IdDetalle, IdPedido, IdServicio, Cantidad, PrecioBase, MontoAdicional, Subtotal)
VALUES
    (2001, 2001, 2001, 2.00, 1800.00, 0.00, 3600.00),
    (2002, 2002, 2002, 1.00, 6500.00, 0.00, 6500.00),
    (2003, 2003, 2003, 2.00, 3000.00, 0.00, 6000.00);

SET IDENTITY_INSERT dbo.DetallePedido OFF;

COMMIT TRANSACTION;
GO

SELECT * FROM dbo.Recolecciones
WHERE IdRecoleccion BETWEEN 2001 AND 2003
ORDER BY IdRecoleccion;

SELECT * FROM dbo.DetallePedido
WHERE IdDetalle BETWEEN 2001 AND 2003
ORDER BY IdDetalle;
GO
