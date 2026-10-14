-- Consultas existentes de Rachel: TipoConsulta=1 -> tabla completa; TipoConsulta=2 -> un ID.
-- Solo ejemplos. Sustituir IDs por los actuales consultados en cada tabla.
USE LavaFacil;
GO
EXEC dbo.ConsultarClientes @TipoConsulta=1;
EXEC dbo.ConsultarEmpleados @TipoConsulta=1;
EXEC dbo.ConsultarServicios @TipoConsulta=1;
EXEC dbo.ConsultarPedidos @TipoConsulta=1;
EXEC dbo.ConsultarDetallePedido @TipoConsulta=1;
EXEC dbo.ConsultarPagos @TipoConsulta=1;
EXEC dbo.ConsultarRecolecciones @TipoConsulta=1;
EXEC dbo.ConsultarPromociones @TipoConsulta=1;
EXEC dbo.ConsultarInventario @TipoConsulta=1;
-- ADVERTENCIA: ConsultarUsuarios devuelve la columna Clave del diseño académico.
-- No capturar ni compartir ese resultado sin ocultar las claves.
-- EXEC dbo.ConsultarUsuarios @TipoConsulta=1;
GO
DECLARE @IdCliente INT=(SELECT MIN(IdCliente) FROM dbo.Clientes);
EXEC dbo.ConsultarClientes @TipoConsulta=2,@IdCliente=@IdCliente;
