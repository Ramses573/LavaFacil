USE LavaFacil;
GO

IF SCHEMA_ID(N'EvidenciaBCPFinal20261117') IS NULL
    EXEC(N'CREATE SCHEMA EvidenciaBCPFinal20261117');
GO

IF OBJECT_ID(N'EvidenciaBCPFinal20261117.Clientes', N'U') IS NULL
    SELECT TOP (0) * INTO EvidenciaBCPFinal20261117.Clientes FROM dbo.Clientes;
IF OBJECT_ID(N'EvidenciaBCPFinal20261117.Servicios', N'U') IS NULL
    SELECT TOP (0) * INTO EvidenciaBCPFinal20261117.Servicios FROM dbo.Servicios;
IF OBJECT_ID(N'EvidenciaBCPFinal20261117.Promociones', N'U') IS NULL
    SELECT TOP (0) * INTO EvidenciaBCPFinal20261117.Promociones FROM dbo.Promociones;
IF OBJECT_ID(N'EvidenciaBCPFinal20261117.Pedidos', N'U') IS NULL
    SELECT TOP (0) * INTO EvidenciaBCPFinal20261117.Pedidos FROM dbo.Pedidos;
IF OBJECT_ID(N'EvidenciaBCPFinal20261117.Pagos', N'U') IS NULL
    SELECT TOP (0) * INTO EvidenciaBCPFinal20261117.Pagos FROM dbo.Pagos;
GO

IF SCHEMA_ID(N'EvidenciaAsistenteFinal20261117') IS NULL
    EXEC(N'CREATE SCHEMA EvidenciaAsistenteFinal20261117');
GO

