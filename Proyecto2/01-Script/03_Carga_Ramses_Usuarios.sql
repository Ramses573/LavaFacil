USE [LavaFacil];
GO

SET XACT_ABORT ON;

IF (SELECT COUNT(*) FROM dbo.Clientes WHERE IdCliente BETWEEN 2001 AND 2003) <> 3
    THROW 50101, 'Faltan los Clientes 2001-2003 requeridos por Usuarios.', 1;

IF (SELECT COUNT(*) FROM dbo.Empleados WHERE IdEmpleado BETWEEN 2001 AND 2003) <> 3
    THROW 50102, 'Faltan los Empleados 2001-2003 requeridos por Usuarios.', 1;

IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IdUsuario BETWEEN 2001 AND 2003)
    THROW 50103, 'Los Usuarios 2001-2003 ya existen. No se realizó la carga.', 1;

BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.Usuarios ON;

INSERT INTO dbo.Usuarios
    (IdUsuario, NombreUsuario, Clave, TipoUsuario, IdCliente, IdEmpleado, Activo, FechaCreacion)
VALUES
    (2001, 'cliente_p2_01',  'DemoTemporal2026!1', 'Cliente',       2001, NULL, 0, '2026-10-24T10:10:00'),
    (2002, 'empleado_p2_01', 'DemoTemporal2026!2', 'Empleado',      NULL, 2001, 0, '2026-10-24T10:10:00'),
    (2003, 'admin_p2_01',     'DemoTemporal2026!3', 'Administrador', NULL, 2003, 0, '2026-10-24T10:10:00');

SET IDENTITY_INSERT dbo.Usuarios OFF;

COMMIT TRANSACTION;
GO

SELECT IdUsuario, NombreUsuario, TipoUsuario, IdCliente, IdEmpleado, Activo, FechaCreacion
FROM dbo.Usuarios
WHERE IdUsuario BETWEEN 2001 AND 2003
ORDER BY IdUsuario;
GO
