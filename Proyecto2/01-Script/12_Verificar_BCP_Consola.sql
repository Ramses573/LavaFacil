USE LavaFacil;
SET NOCOUNT ON;
SELECT 'Usuarios' Tabla, COUNT(*) Filas, MIN(IdUsuario) PrimerID, MAX(IdUsuario) UltimoID
FROM EvidenciaConsolaFinal.Usuarios
UNION ALL
SELECT 'Recolecciones',COUNT(*),MIN(IdRecoleccion),MAX(IdRecoleccion)
FROM EvidenciaConsolaFinal.Recolecciones
UNION ALL
SELECT 'DetallePedido',COUNT(*),MIN(IdDetalle),MAX(IdDetalle)
FROM EvidenciaConsolaFinal.DetallePedido;
SELECT IdUsuario,IdCliente,IdEmpleado FROM EvidenciaConsolaFinal.Usuarios ORDER BY IdUsuario;
