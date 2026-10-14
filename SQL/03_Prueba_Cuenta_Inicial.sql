USE LavaFacil;
GO
SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM dbo.Usuarios)
BEGIN
    PRINT 'Prueba omitida: ya existen cuentas reales. No se modificó ninguna.';
    RETURN;
END;
DECLARE @Marca VARCHAR(32)=REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
DECLARE @Cedula VARCHAR(20)=LEFT(@Marca,20),@Email VARCHAR(150)=@Marca+'@example.test',@Cuenta VARCHAR(50)='initial_'+@Marca;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.app_CrearAdministradorInicial @Cedula,'Prueba','Inicial','88888888',@Email,@Cuenta,'SoloPruebaTemporal';
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios u INNER JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.NombreUsuario=@Cuenta AND u.TipoUsuario='Administrador' AND e.Nombre='Prueba' AND e.Activo=1)
        THROW 50210,'No se creó el administrador inicial correctamente.',1;
    PRINT 'PASS: primera cuenta y perfil vinculados correctamente.';
    BEGIN TRY
        EXEC dbo.app_CrearAdministradorInicial @Cedula,'Prueba','Duplicada','88888888',@Email,@Cuenta,'SoloPruebaTemporal';
        THROW 50211,'Se permitió crear una segunda cuenta inicial.',1;
    END TRY BEGIN CATCH
        IF ERROR_NUMBER()<>50102 THROW;
        PRINT 'PASS: la creación inicial se bloquea cuando ya existe una cuenta.';
    END CATCH;
    IF @@TRANCOUNT>0 ROLLBACK;
    SELECT COUNT(*) AS UsuariosDespuesPrueba,@@TRANCOUNT AS TransaccionesAbiertas FROM dbo.Usuarios;
END TRY BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
