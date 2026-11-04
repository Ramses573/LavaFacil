USE LavaFacil;
SET NOCOUNT ON;
SELECT 'Usuarios' Tabla, COUNT(*) Filas, MIN(IdUsuario) PrimerID, MAX(IdUsuario) UltimoID
FROM EvidenciaSSMS20261104.Usuarios
UNION ALL
SELECT 'Recolecciones', COUNT(*), MIN(IdRecoleccion), MAX(IdRecoleccion)
FROM EvidenciaSSMS20261104.Recolecciones
UNION ALL
SELECT 'DetallePedido', COUNT(*), MIN(IdDetalle), MAX(IdDetalle)
FROM EvidenciaSSMS20261104.DetallePedido;
SELECT IdUsuario, NombreUsuario, TipoUsuario, IdCliente, IdEmpleado, Activo
FROM EvidenciaSSMS20261104.Usuarios ORDER BY IdUsuario;
SELECT IdRecoleccion, IdPedido, Estado
FROM EvidenciaSSMS20261104.Recolecciones ORDER BY IdRecoleccion;
SELECT IdDetalle, IdPedido, IdServicio, Cantidad, Subtotal
FROM EvidenciaSSMS20261104.DetallePedido ORDER BY IdDetalle;
