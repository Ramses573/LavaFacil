:ON ERROR EXIT
-- Requiere modo SQLCMD de SSMS o sqlcmd -b. Se detiene al primer error.
-- ==============================================================================
-- PROYECTO 2: CARGA MASIVA DE DATOS MEDIANTE BULK INSERT (TRANSACT-SQL)
-- Curso: TI-156 Bases de Datos Avanzadas
-- Integrantes: José Ramsés Aguilar & Rachel Rosales
-- Base de Datos: LavaFacil
--
-- DESCRIPCIÓN:
-- Demuestra el tercer método de carga masiva visto en clase: la instrucción
-- SQL 'BULK INSERT' ejecutada directamente en el motor de base de datos.
-- ==============================================================================

USE [LavaFacil];
GO
-- Esta carga corresponde a una base sin los IDs de prueba. Para una base ya
-- cargada use 08_Demostracion_BULK_INSERT_Segura.sql.
IF EXISTS (SELECT 1 FROM dbo.Clientes WHERE IdCliente BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Empleados WHERE IdEmpleado BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Servicios WHERE IdServicio BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Promociones WHERE IdPromocion BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Inventario WHERE IdInventario BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IdUsuario BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Pedidos WHERE IdPedido BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Recolecciones WHERE IdRecoleccion BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.DetallePedido WHERE IdDetalle BETWEEN 2001 AND 2003)
 OR EXISTS (SELECT 1 FROM dbo.Pagos WHERE IdPago BETWEEN 2001 AND 2003)
    THROW 51000, 'Ya existen IDs 2001 a 2003. No ejecute esta carga; use el script 08 de demostración aislada.', 1;
-- En SSMS active Consulta > Modo SQLCMD y :ON ERROR EXIT para detener todos
-- los lotes al primer error. Alternativa: sqlcmd -b -i este_archivo.sql.
GO

PRINT '=======================================================';
PRINT 'INICIANDO CARGA MASIVA CON BULK INSERT (TRANSACT-SQL)';
PRINT '=======================================================';
GO

-- NOTA: Modificar la ruta base si los archivos se encuentran en otra ubicación.
-- Rutas locales absolutas en el entorno de desarrollo:
-- C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\
-- C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\

-- ------------------------------------------------------------------------------
-- 1. TABLA: Clientes (Archivo: 01_Clientes.csv)
-- ------------------------------------------------------------------------------
PRINT '1. Cargando dbo.Clientes con BULK INSERT...';
BULK INSERT dbo.Clientes
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\01_Clientes.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 2. TABLA: Empleados (Archivo: 02_Empleados.csv)
-- ------------------------------------------------------------------------------
PRINT '2. Cargando dbo.Empleados con BULK INSERT...';
BULK INSERT dbo.Empleados
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\02_Empleados.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 3. TABLA: Servicios (Archivo: 03_Servicios.csv)
-- ------------------------------------------------------------------------------
PRINT '3. Cargando dbo.Servicios con BULK INSERT...';
BULK INSERT dbo.Servicios
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\03_Servicios.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 4. TABLA: Promociones (Archivo: 04_Promociones.csv)
-- ------------------------------------------------------------------------------
PRINT '4. Cargando dbo.Promociones con BULK INSERT...';
BULK INSERT dbo.Promociones
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\04_Promociones.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 5. TABLA: Inventario (Archivo: 05_Inventario.csv)
-- ------------------------------------------------------------------------------
PRINT '5. Cargando dbo.Inventario con BULK INSERT...';
BULK INSERT dbo.Inventario
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\05_Inventario.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 6. TABLA: Usuarios (Archivo: 06_Usuarios.csv)
-- ------------------------------------------------------------------------------
PRINT '6. Cargando dbo.Usuarios con BULK INSERT...';
BULK INSERT dbo.Usuarios
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\06_Usuarios.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 7. TABLA: Pedidos (Archivo: 07_Pedidos.csv)
-- ------------------------------------------------------------------------------
PRINT '7. Cargando dbo.Pedidos con BULK INSERT...';
BULK INSERT dbo.Pedidos
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\07_Pedidos.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 8. TABLA: Recolecciones (Archivo: 08_Recolecciones.csv)
-- ------------------------------------------------------------------------------
PRINT '8. Cargando dbo.Recolecciones con BULK INSERT...';
BULK INSERT dbo.Recolecciones
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\08_Recolecciones.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

-- ------------------------------------------------------------------------------
-- 9. TABLA: DetallePedido (Archivo: 09_DetallePedido.csv)
-- ------------------------------------------------------------------------------
PRINT '9. Cargando dbo.DetallePedido con BULK INSERT...';
BULK INSERT dbo.DetallePedido
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\09_DetallePedido.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS,
    FIRE_TRIGGERS
);
GO

-- ------------------------------------------------------------------------------
-- 10. TABLA: Pagos (Archivo: 10_Pagos.csv)
-- ------------------------------------------------------------------------------
PRINT '10. Cargando dbo.Pagos con BULK INSERT...';
BULK INSERT dbo.Pagos
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Rachel-BCP\10_Pagos.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    KEEPIDENTITY,
    CHECK_CONSTRAINTS
);
GO

PRINT '=======================================================';
PRINT 'CARGA CON BULK INSERT COMPLETADA EXITOSAMENTE';
PRINT '=======================================================';
GO

-- VERIFICACIÓN INMEDIATA DE REGISTROS CARGADOS
SELECT 'Clientes' AS Tabla, COUNT(*) AS Total FROM dbo.Clientes WHERE IdCliente BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Empleados', COUNT(*) FROM dbo.Empleados WHERE IdEmpleado BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Servicios', COUNT(*) FROM dbo.Servicios WHERE IdServicio BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Promociones', COUNT(*) FROM dbo.Promociones WHERE IdPromocion BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Inventario', COUNT(*) FROM dbo.Inventario WHERE IdInventario BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Usuarios', COUNT(*) FROM dbo.Usuarios WHERE IdUsuario BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Pedidos', COUNT(*) FROM dbo.Pedidos WHERE IdPedido BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Recolecciones', COUNT(*) FROM dbo.Recolecciones WHERE IdRecoleccion BETWEEN 2001 AND 2003
UNION ALL
SELECT 'DetallePedido', COUNT(*) FROM dbo.DetallePedido WHERE IdDetalle BETWEEN 2001 AND 2003
UNION ALL
SELECT 'Pagos', COUNT(*) FROM dbo.Pagos WHERE IdPago BETWEEN 2001 AND 2003;
GO
