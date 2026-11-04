USE LavaFacil;
GO
-- Preparación para repetir cargas sin borrar ni duplicar datos de dbo.
IF SCHEMA_ID('EvidenciaSSMS20261104') IS NULL
    EXEC('CREATE SCHEMA EvidenciaSSMS20261104');
GO
IF OBJECT_ID('EvidenciaSSMS20261104.Inventario') IS NULL
BEGIN
    SELECT TOP (0) * INTO EvidenciaSSMS20261104.Inventario FROM dbo.Inventario;
    -- Recepción de texto para evitar la conversión decimal del proveedor .NET.
    ALTER TABLE EvidenciaSSMS20261104.Inventario ALTER COLUMN Cantidad varchar(50) NOT NULL;
    ALTER TABLE EvidenciaSSMS20261104.Inventario ALTER COLUMN CantidadMinima varchar(50) NOT NULL;
END;
IF OBJECT_ID('EvidenciaSSMS20261104.Usuarios') IS NULL
    SELECT TOP (0) * INTO EvidenciaSSMS20261104.Usuarios FROM dbo.Usuarios;
IF OBJECT_ID('EvidenciaSSMS20261104.Recolecciones') IS NULL
    SELECT TOP (0) * INTO EvidenciaSSMS20261104.Recolecciones FROM dbo.Recolecciones;
IF OBJECT_ID('EvidenciaSSMS20261104.DetallePedido') IS NULL
    SELECT TOP (0) * INTO EvidenciaSSMS20261104.DetallePedido FROM dbo.DetallePedido;
GO
