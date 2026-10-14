USE LavaFacil;
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@SERVERNAME <> N'MADRENZO'
    THROW 50000, 'Se esperaba MADRENZO después del regreso. No se borró nada.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID() AND mirroring_role_desc=N'PRINCIPAL' AND mirroring_state_desc=N'SYNCHRONIZED')
    THROW 50000, 'No se confirmó principal sincronizado. No se borró nada.', 1;
BEGIN TRY
 BEGIN TRANSACTION;
 DELETE FROM dbo.Clientes
 WHERE IdCliente=7 AND Cedula='QA-FAILOVER-20261011'
 AND Nombre='Prueba Conmutacion' AND Apellidos='Cliente Ficticio'
 AND Email='failover-20261011@example.test' AND Telefono='00000000'
 AND Direccion='REGISTRO TEMPORAL de prueba de conmutacion; eliminar despues de las capturas.';
 IF @@ROWCOUNT <> 1
     THROW 50000, 'No se encontró exactamente el cliente de prueba esperado. Revisar antes de continuar.', 1;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
SELECT @@SERVERNAME AS Servidor, N'Únicamente el cliente ficticio ID 7 fue eliminado.' AS Resultado;
SELECT COUNT(*) AS CoincidenciasRestantes FROM dbo.Clientes WHERE IdCliente=7 OR Cedula='QA-FAILOVER-20261011' OR Email='failover-20261011@example.test';
SELECT NombreUsuario,TipoUsuario,Activo FROM dbo.Usuarios WHERE NombreUsuario=N'ramses.aguilar';
SELECT mirroring_role_desc AS Rol,mirroring_state_desc AS Estado FROM sys.database_mirroring WHERE database_id=DB_ID();
