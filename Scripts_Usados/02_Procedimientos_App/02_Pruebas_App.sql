USE LavaFacil;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @Resultados TABLE(Prueba NVARCHAR(150), Resultado VARCHAR(10));
DECLARE @Marca VARCHAR(32)=REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
DECLARE @Admin INT, @Cliente INT, @Empleado INT, @UsuarioCliente INT;
DECLARE @CedulaRegistro VARCHAR(20)=LEFT(@Marca,19)+'R';
DECLARE @EmailRegistro VARCHAR(150)=@Marca+'r@example.test',@EmailPerfil VARCHAR(150)=@Marca+'p@example.test';
BEGIN TRY
  BEGIN TRANSACTION;
  INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso)
  VALUES(LEFT(@Marca,20),'Prueba','App','88888888',@Marca+'@example.test','Administrador',CONVERT(DATE,GETDATE()));
  SET @Empleado=SCOPE_IDENTITY();
  INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdEmpleado)
  VALUES('test_'+@Marca,'SoloPruebaTemporal','Administrador',@Empleado);
  SET @Admin=SCOPE_IDENTITY();
  INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email)
  VALUES(LEFT(@Marca,18)+'C','Cliente','Temporal','88888888',@Marca+'c@example.test');
  SET @Cliente=SCOPE_IDENTITY();
  INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdCliente)
  VALUES('cliente_'+@Marca,'SoloPruebaTemporal','Cliente',@Cliente);
  SET @UsuarioCliente=SCOPE_IDENTITY();
  DECLARE @Login TABLE(LoginValido BIT, IdUsuario INT,NombreUsuario VARCHAR(50),TipoUsuario VARCHAR(20),IdCliente INT,IdEmpleado INT);
  DECLARE @NombreUsuario VARCHAR(50)='test_'+@Marca;
  INSERT @Login EXEC dbo.usp_ValidarLogin @NombreUsuario,'SoloPruebaTemporal';
  IF NOT EXISTS(SELECT 1 FROM @Login WHERE LoginValido=1 AND IdUsuario=@Admin) THROW 50201,'Falló el login de prueba.',1;
  INSERT @Resultados VALUES('Login de administrador vinculado a empleado activo','PASS');
  EXEC dbo.app_Resumen @Admin;
  INSERT @Resultados VALUES('Resumen real de la base','PASS');
  EXEC dbo.app_ConsultarServicios @UsuarioCliente;
  INSERT @Resultados VALUES('Cliente puede consultar servicios','PASS');
  EXEC dbo.app_ConsultarClientes @Admin;
  INSERT @Resultados VALUES('Administrador puede consultar clientes','PASS');
  EXEC dbo.app_RegistrarCliente @Admin, @CedulaRegistro, 'Registro', 'Prueba', '88888888', @EmailRegistro;
  IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE Cedula=@CedulaRegistro AND Nombre='Registro') THROW 50202,'Falló el registro.',1;
  INSERT @Resultados VALUES('Registro mediante SP persiste los datos','PASS');
  EXEC dbo.app_ActualizarPerfil @Admin,'Editado','Perfil','87777777',@EmailPerfil;
  IF NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@Empleado AND Nombre='Editado' AND Email=@EmailPerfil) THROW 50203,'Falló el perfil.',1;
  INSERT @Resultados VALUES('Perfil edita únicamente el empleado de la cuenta','PASS');
  BEGIN TRY
    EXEC dbo.app_ConsultarClientes @UsuarioCliente;
    THROW 50204,'Cliente pudo consultar clientes ajenos.',1;
  END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>50100 THROW;
    INSERT @Resultados VALUES('Cliente sin permiso para consultar clientes ajenos','PASS');
  END CATCH;
  UPDATE dbo.Usuarios SET Activo=0 WHERE IdUsuario=@Admin;
  BEGIN TRY
    EXEC dbo.app_ConsultarPerfil @Admin;
    THROW 50205,'Cuenta inactiva pudo consultar el perfil.',1;
  END TRY BEGIN CATCH
    IF ERROR_NUMBER()<>50100 THROW;
    INSERT @Resultados VALUES('Cuenta desactivada pierde el acceso','PASS');
  END CATCH;
  ROLLBACK TRANSACTION;
  SELECT * FROM @Resultados;
  SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseDatos,@@TRANCOUNT AS TransaccionesAbiertas,
    (SELECT COUNT(*) FROM dbo.Usuarios) AS UsuariosReales,
    (SELECT COUNT(*) FROM dbo.Clientes) AS ClientesReales,
    (SELECT COUNT(*) FROM dbo.Servicios) AS ServiciosReales;
END TRY BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO
