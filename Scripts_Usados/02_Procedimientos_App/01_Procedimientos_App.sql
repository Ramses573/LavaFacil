USE [LavaFacil];
GO
CREATE OR ALTER PROCEDURE dbo.app_EstadoInicial
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(BIT,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuarios) THEN 0 ELSE 1 END) AS RequiereAdministrador;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearAdministradorInicial
    @Cedula VARCHAR(20),@Nombre VARCHAR(50),@Apellidos VARCHAR(100),@Telefono VARCHAR(20),
    @Email VARCHAR(150),@NombreUsuario VARCHAR(50),@Clave VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@NombreUsuario)),'') IS NULL
       OR DATALENGTH(@Clave)<8
       THROW 50101,'Completa los datos y usa una contraseña de al menos 8 caracteres.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(TABLOCKX,HOLDLOCK))
            THROW 50102,'Ya existen cuentas. La creación inicial ya no está disponible.',1;
        INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso)
        VALUES(@Cedula,@Nombre,@Apellidos,@Telefono,@Email,'Administrador',CONVERT(DATE,GETDATE()));
        DECLARE @IdEmpleado INT=SCOPE_IDENTITY();
        INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdEmpleado)
        VALUES(@NombreUsuario,@Clave,'Administrador',@IdEmpleado);
        DECLARE @IdUsuario INT=SCOPE_IDENTITY();
        COMMIT TRANSACTION;
        SELECT @IdUsuario AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Complementos de Ramses para el miniaplicativo. No reemplaza SPs ni triggers existentes.
-- Se valida el estado actual de la cuenta en cada operación, no solo el rol de la cookie.
CREATE OR ALTER PROCEDURE dbo.app_Autorizar
    @IdUsuario INT, @SoloPersonal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios u
        LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.IdUsuario=@IdUsuario AND u.Activo=1
          AND ((u.TipoUsuario='Cliente' AND c.Activo=1 AND @SoloPersonal=0)
          OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1))
    ) THROW 50100, 'La cuenta está inactiva o no tiene permiso para esta operación.', 1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_Resumen @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT (SELECT COUNT(*) FROM dbo.Servicios WHERE Activo=1) AS ServiciosActivos,
      CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario IN ('Empleado','Administrador'))
      THEN (SELECT COUNT(*) FROM dbo.Clientes WHERE Activo=1) ELSE NULL END AS ClientesActivos;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ConsultarServicios @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT IdServicio, NombreServicio, Descripcion, TipoCobro, PrecioBase,
      CantidadIncluida, PrecioAdicional, Activo
    FROM dbo.Servicios WHERE Activo=1 ORDER BY NombreServicio;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ConsultarClientes @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario, 1;
    SELECT IdCliente, Cedula, Nombre, Apellidos, Telefono, Email, Direccion, FechaRegistro, Activo
    FROM dbo.Clientes ORDER BY FechaRegistro DESC, IdCliente DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_RegistrarCliente
    @IdUsuario INT, @Cedula VARCHAR(20), @Nombre VARCHAR(50), @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(150), @Direccion VARCHAR(250)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario, 1;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL
       THROW 50101, 'Completa todos los datos obligatorios del cliente.', 1;
    INSERT dbo.Clientes (Cedula,Nombre,Apellidos,Telefono,Email,Direccion)
    VALUES (@Cedula,@Nombre,@Apellidos,@Telefono,@Email,NULLIF(@Direccion,''));
    SELECT CONVERT(INT,SCOPE_IDENTITY()) AS IdCliente;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ConsultarPerfil @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT u.NombreUsuario,u.TipoUsuario,COALESCE(c.Nombre,e.Nombre) AS Nombre,
      COALESCE(c.Apellidos,e.Apellidos) AS Apellidos,COALESCE(c.Cedula,e.Cedula) AS Cedula,
      COALESCE(c.Telefono,e.Telefono) AS Telefono,COALESCE(c.Email,e.Email) AS Email
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
      LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado WHERE u.IdUsuario=@IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ActualizarPerfil
    @IdUsuario INT, @Nombre VARCHAR(50), @Apellidos VARCHAR(100), @Telefono VARCHAR(20), @Email VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL
       THROW 50101, 'Completa los datos obligatorios del perfil.', 1;
    DECLARE @IdCliente INT, @IdEmpleado INT;
    SELECT @IdCliente=IdCliente,@IdEmpleado=IdEmpleado FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario;
    IF @IdCliente IS NOT NULL UPDATE dbo.Clientes SET Nombre=@Nombre,Apellidos=@Apellidos,Telefono=@Telefono,Email=@Email WHERE IdCliente=@IdCliente;
    ELSE UPDATE dbo.Empleados SET Nombre=@Nombre,Apellidos=@Apellidos,Telefono=@Telefono,Email=@Email WHERE IdEmpleado=@IdEmpleado;
    EXEC dbo.app_ConsultarPerfil @IdUsuario;
END;
GO
