USE LavaFacil;
GO
-- Preparacion para repetir BCP sin modificar las tablas dbo.
-- Ejecutar una sola vez. Las tablas auxiliares no copian llaves foraneas ni triggers.
CREATE SCHEMA EvidenciaConsolaFinal;
GO
SELECT TOP(0) * INTO EvidenciaConsolaFinal.Usuarios FROM dbo.Usuarios;
SELECT TOP(0) * INTO EvidenciaConsolaFinal.Recolecciones FROM dbo.Recolecciones;
SELECT TOP(0) * INTO EvidenciaConsolaFinal.DetallePedido FROM dbo.DetallePedido;
