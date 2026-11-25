-- Mantenimientos del proyecto final: empleados, usuarios, inventario, promociones,
-- recolectos, pagos, empresa y borrado seguro de servicios.
-- Idempotente: se puede ejecutar varias veces sobre la misma base.
-- Todo pasa por app_Autorizar/app_ExigirAdministrador: el id de usuario llega por la cookie.
USE [LavaFacil];
GO
SET NOCOUNT ON;
GO

-- La activación de cuentas (07_Activacion_Y_Borrado.sql) agrega esta columna.
-- Se crea aquí también para que este script funcione por sí solo si se ejecuta
-- antes que 07; 07 repite la comprobación sin problema.
IF COL_LENGTH('dbo.Usuarios','ActivacionPendiente') IS NULL
    ALTER TABLE dbo.Usuarios
        ADD ActivacionPendiente BIT NOT NULL
            CONSTRAINT DF_Usuarios_ActivacionPendiente DEFAULT(0);
GO

-- Informacion general de la empresa (una sola fila visible).
IF OBJECT_ID('dbo.Empresa','U') IS NULL
BEGIN
    CREATE TABLE dbo.Empresa(
        IdEmpresa INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empresa PRIMARY KEY,
        Nombre VARCHAR(150) NOT NULL,
        Eslogan VARCHAR(200) NOT NULL CONSTRAINT DF_Empresa_Eslogan DEFAULT(''),
        Descripcion NVARCHAR(1000) NOT NULL CONSTRAINT DF_Empresa_Descripcion DEFAULT(''),
        Telefono VARCHAR(20) NOT NULL CONSTRAINT DF_Empresa_Telefono DEFAULT(''),
        Email VARCHAR(150) NOT NULL CONSTRAINT DF_Empresa_Email DEFAULT(''),
        Direccion VARCHAR(250) NOT NULL CONSTRAINT DF_Empresa_Direccion DEFAULT(''),
        Horario VARCHAR(200) NOT NULL CONSTRAINT DF_Empresa_Horario DEFAULT(''),
        Facebook VARCHAR(200) NOT NULL CONSTRAINT DF_Empresa_Facebook DEFAULT(''),
        Instagram VARCHAR(200) NOT NULL CONSTRAINT DF_Empresa_Instagram DEFAULT('')
    );
END;
IF NOT EXISTS(SELECT 1 FROM dbo.Empresa)
    INSERT dbo.Empresa(Nombre,Eslogan,Descripcion,Telefono,Email,Direccion,Horario,Facebook,Instagram)
    VALUES('LavaFácil','Tu ropa limpia, sin complicaciones',
        N'Lavandería en línea: solicita el servicio, consulta tus pedidos y recibe tu ropa lista en el local.',
        '8888-8888','contacto@lavafacil.cr','San José, Costa Rica','Lunes a sábado, 7:00 a 18:00','','');
GO
CREATE OR ALTER PROCEDURE dbo.app_EmpresaPublica
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(1) Nombre,Eslogan,Descripcion,Telefono,Email,Direccion,Horario,Facebook,Instagram
    FROM dbo.Empresa ORDER BY IdEmpresa;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarEmpresa
    @IdUsuario INT,@Nombre VARCHAR(150),@Eslogan VARCHAR(200)='',@Descripcion NVARCHAR(1000)='',
    @Telefono VARCHAR(20)='',@Email VARCHAR(150)='',@Direccion VARCHAR(250)='',
    @Horario VARCHAR(200)='',@Facebook VARCHAR(200)='',@Instagram VARCHAR(200)=''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
        THROW 50101,'El nombre de la empresa es obligatorio.',1;
    UPDATE dbo.Empresa SET Nombre=LTRIM(RTRIM(@Nombre)),Eslogan=@Eslogan,Descripcion=@Descripcion,
        Telefono=@Telefono,Email=@Email,Direccion=@Direccion,Horario=@Horario,Facebook=@Facebook,Instagram=@Instagram
    WHERE IdEmpresa=(SELECT TOP(1) IdEmpresa FROM dbo.Empresa ORDER BY IdEmpresa);
    IF @@ROWCOUNT=0
        INSERT dbo.Empresa(Nombre,Eslogan,Descripcion,Telefono,Email,Direccion,Horario,Facebook,Instagram)
        VALUES(LTRIM(RTRIM(@Nombre)),@Eslogan,@Descripcion,@Telefono,@Email,@Direccion,@Horario,@Facebook,@Instagram);
    SELECT TOP(1) Nombre,Eslogan,Descripcion,Telefono,Email,Direccion,Horario,Facebook,Instagram
    FROM dbo.Empresa ORDER BY IdEmpresa;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ServiciosPublicos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdServicio,NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,PrecioAdicional
    FROM dbo.Servicios WHERE Activo=1 ORDER BY NombreServicio;
END;
GO

-- Empleados
CREATE OR ALTER PROCEDURE dbo.app_ConsultarEmpleados
    @IdUsuario INT,@Busqueda VARCHAR(100)='',@IncluirInactivos BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    SELECT e.IdEmpleado,e.Cedula,e.Nombre,e.Apellidos,e.Telefono,e.Email,e.Cargo,e.FechaIngreso,e.Activo,
        (SELECT COUNT(*) FROM dbo.Usuarios u WHERE u.IdEmpleado=e.IdEmpleado) AS Cuentas
    FROM dbo.Empleados e
    WHERE (e.Activo=1 OR @IncluirInactivos=1)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(e.Nombre,' ',e.Apellidos,' ',e.Cedula,' ',e.Email,' ',e.Cargo))>0)
    ORDER BY e.Nombre,e.Apellidos;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarEmpleado
    @IdUsuario INT,@IdEmpleado INT=NULL,@Cedula VARCHAR(20),@Nombre VARCHAR(50),@Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),@Email VARCHAR(150),@Cargo VARCHAR(30),@FechaIngreso DATE=NULL,@Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL OR @Cargo NOT IN ('Administrador','Empleado')
        THROW 50101,'Completa los datos y revisa el cargo del empleado.',1;
    IF EXISTS(SELECT 1 FROM dbo.Empleados WHERE Cedula=LTRIM(RTRIM(@Cedula)) AND (@IdEmpleado IS NULL OR IdEmpleado<>@IdEmpleado))
        THROW 50101,'Ya existe un empleado con esa cédula.',1;
    IF EXISTS(SELECT 1 FROM dbo.Empleados WHERE Email=LTRIM(RTRIM(@Email)) AND (@IdEmpleado IS NULL OR IdEmpleado<>@IdEmpleado))
        THROW 50101,'Ya existe un empleado con ese correo.',1;
    IF @IdEmpleado IS NULL
    BEGIN
        INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso,Activo)
        VALUES(LTRIM(RTRIM(@Cedula)),LTRIM(RTRIM(@Nombre)),LTRIM(RTRIM(@Apellidos)),LTRIM(RTRIM(@Telefono)),
            LTRIM(RTRIM(@Email)),@Cargo,ISNULL(@FechaIngreso,CONVERT(DATE,GETDATE())),@Activo);
        SET @IdEmpleado=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Empleados SET Cedula=LTRIM(RTRIM(@Cedula)),Nombre=LTRIM(RTRIM(@Nombre)),Apellidos=LTRIM(RTRIM(@Apellidos)),
            Telefono=LTRIM(RTRIM(@Telefono)),Email=LTRIM(RTRIM(@Email)),Cargo=@Cargo,
            FechaIngreso=ISNULL(@FechaIngreso,FechaIngreso),Activo=@Activo
        WHERE IdEmpleado=@IdEmpleado;
        IF @@ROWCOUNT=0 THROW 50104,'El empleado no existe.',1;
    END;
    SELECT @IdEmpleado AS IdEmpleado;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoEmpleado @IdUsuario INT,@IdEmpleado INT,@Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @Activo=0 AND @IdEmpleado=(SELECT IdEmpleado FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario)
        THROW 50101,'No puedes desactivar el empleado de tu propia cuenta.',1;
    IF @Activo=0 AND EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@IdEmpleado AND Cargo='Administrador' AND Activo=1)
       AND NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE Cargo='Administrador' AND Activo=1 AND IdEmpleado<>@IdEmpleado)
        THROW 50101,'Debe quedar al menos un empleado administrador activo.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.Empleados SET Activo=@Activo WHERE IdEmpleado=@IdEmpleado;
        IF @@ROWCOUNT=0
        BEGIN
            ROLLBACK;
            THROW 50104,'El empleado no existe.',1;
        END;
        -- Una cuenta de acceso no puede quedar activa si su empleado fue desactivado.
        IF @Activo=0 UPDATE dbo.Usuarios SET Activo=0 WHERE IdEmpleado=@IdEmpleado;
        COMMIT;
        SELECT @IdEmpleado AS IdEmpleado,@Activo AS Activo;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK; THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarEmpleado @IdUsuario INT,@IdEmpleado INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@IdEmpleado)
        THROW 50104,'El empleado no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdEmpleado=@IdEmpleado)
        THROW 50101,'El empleado tiene una cuenta de acceso. Elimina la cuenta o desactívalo para conservar el historial.',1;
    DELETE dbo.Empleados WHERE IdEmpleado=@IdEmpleado;
    SELECT @IdEmpleado AS IdEmpleado;
END;
GO

-- Usuarios (solo administradores)
CREATE OR ALTER PROCEDURE dbo.app_ConsultarUsuarios
    @IdUsuario INT,@Busqueda VARCHAR(100)='',@IncluirInactivos BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    SELECT u.IdUsuario,u.NombreUsuario,u.TipoUsuario,u.Activo,u.FechaCreacion,u.IdCliente,u.IdEmpleado,
        COALESCE(c.Nombre,e.Nombre) AS Nombre,COALESCE(c.Apellidos,e.Apellidos) AS Apellidos,
        CASE WHEN u.EmailVerificado IS NULL THEN 0 ELSE 1 END AS CorreoVerificado,
        ISNULL(u.ActivacionPendiente,0) AS ActivacionPendiente
    FROM dbo.Usuarios u
    LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE (u.Activo=1 OR @IncluirInactivos=1)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(u.NombreUsuario,' ',u.TipoUsuario,' ',
            COALESCE(c.Nombre,e.Nombre),' ',COALESCE(c.Apellidos,e.Apellidos)))>0)
    ORDER BY u.TipoUsuario,u.NombreUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarUsuario
    @IdUsuario INT,@IdUsuarioObjetivo INT=NULL,@NombreUsuario VARCHAR(50),@TipoUsuario VARCHAR(20),
    @IdCliente INT=NULL,@IdEmpleado INT=NULL,@Activo BIT=1,@NuevoHash VARCHAR(255)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NULLIF(LTRIM(RTRIM(@NombreUsuario)),'') IS NULL OR @TipoUsuario NOT IN ('Cliente','Empleado','Administrador')
        THROW 50101,'Revisa el nombre de usuario y el rol.',1;
    IF @TipoUsuario='Cliente' AND (@IdCliente IS NULL OR @IdEmpleado IS NOT NULL)
        THROW 50101,'Un cliente debe tener un cliente asociado y ningún empleado.',1;
    IF @TipoUsuario<>'Cliente' AND (@IdEmpleado IS NULL OR @IdCliente IS NOT NULL)
        THROW 50101,'Un empleado o administrador debe tener un empleado asociado y ningún cliente.',1;
    IF @TipoUsuario='Cliente' AND NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente AND Activo=1)
        THROW 50101,'El cliente no existe o está inactivo.',1;
    IF @TipoUsuario<>'Cliente' AND NOT EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@IdEmpleado AND Activo=1)
        THROW 50101,'El empleado no existe o está inactivo.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario=LTRIM(RTRIM(@NombreUsuario)) AND (@IdUsuarioObjetivo IS NULL OR IdUsuario<>@IdUsuarioObjetivo))
        THROW 50101,'Ese nombre de usuario ya está en uso.',1;
    IF @IdUsuarioObjetivo IS NULL AND @NuevoHash IS NULL
        THROW 50101,'La contraseña inicial es obligatoria para una cuenta nueva.',1;
    if @NuevoHash IS NOT NULL AND (LEFT(@NuevoHash,14)<>'PBKDF2-SHA256$' OR DATALENGTH(@NuevoHash)>250)
        THROW 50101,'No se pudo preparar la contraseña para guardarla.',1;
    IF @IdUsuarioObjetivo=@IdUsuario AND (@Activo=0 OR @TipoUsuario<>'Administrador')
        THROW 50101,'No puedes desactivar tu cuenta ni quitarte el rol de administrador.',1;
    IF @IdUsuarioObjetivo IS NOT NULL AND @Activo=0
       AND NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE TipoUsuario='Administrador' AND Activo=1 AND IdUsuario<>@IdUsuarioObjetivo)
        THROW 50101,'Debe quedar al menos un administrador activo.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @IdUsuarioObjetivo IS NULL
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE IdCliente=@IdCliente AND @IdCliente IS NOT NULL)
                THROW 50101,'Ese cliente ya tiene una cuenta de acceso.',1;
            INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdCliente,IdEmpleado,Activo)
            VALUES(LTRIM(RTRIM(@NombreUsuario)),CONVERT(VARCHAR(255),NEWID()),@NuevoHash,@TipoUsuario,@IdCliente,@IdEmpleado,@Activo);
            SET @IdUsuarioObjetivo=CONVERT(INT,SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            UPDATE dbo.Usuarios SET NombreUsuario=LTRIM(RTRIM(@NombreUsuario)),TipoUsuario=@TipoUsuario,
                IdCliente=@IdCliente,IdEmpleado=@IdEmpleado,Activo=@Activo WHERE IdUsuario=@IdUsuarioObjetivo;
            IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50104,'La cuenta no existe.',1; END;
            IF @NuevoHash IS NOT NULL
                UPDATE dbo.Usuarios SET ClaveHash=@NuevoHash,Clave=CONVERT(VARCHAR(255),NEWID()),ClaveVersion=ClaveVersion+1
                WHERE IdUsuario=@IdUsuarioObjetivo;
        END;
        COMMIT;
        SELECT @IdUsuarioObjetivo AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK; THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoUsuario @IdUsuario INT,@IdUsuarioObjetivo INT,@Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    if @IdUsuarioObjetivo=@IdUsuario AND @Activo=0
        THROW 50101,'No puedes desactivar tu propia cuenta.',1;
    IF @Activo=0 AND NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE TipoUsuario='Administrador' AND Activo=1 AND IdUsuario<>@IdUsuarioObjetivo)
        THROW 50101,'Debe quedar al menos un administrador activo.',1;
    UPDATE dbo.Usuarios SET Activo=@Activo,
        ActivacionPendiente=CASE WHEN @Activo=1 THEN 0 ELSE ActivacionPendiente END
    WHERE IdUsuario=@IdUsuarioObjetivo;
    IF @@ROWCOUNT=0 THROW 50104,'La cuenta no existe.',1;
    SELECT @IdUsuarioObjetivo AS IdUsuario,@Activo AS Activo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarUsuario @IdUsuario INT,@IdUsuarioObjetivo INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF @IdUsuarioObjetivo=@IdUsuario
        THROW 50101,'No puedes eliminar tu propia cuenta.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuarioObjetivo)
        THROW 50104,'La cuenta no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE TipoUsuario='Administrador' AND Activo=1 AND IdUsuario=@IdUsuarioObjetivo)
       AND NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE TipoUsuario='Administrador' AND Activo=1 AND IdUsuario<>@IdUsuarioObjetivo)
        THROW 50101,'Debe quedar al menos un administrador activo.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE dbo.TokensCorreo WHERE IdUsuario=@IdUsuarioObjetivo;
        DELETE dbo.PerfilesApp WHERE IdUsuario=@IdUsuarioObjetivo;
        DELETE dbo.Usuarios WHERE IdUsuario=@IdUsuarioObjetivo;
        IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50104,'La cuenta no existe.',1; END;
        COMMIT;
        SELECT @IdUsuarioObjetivo AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK; THROW;
    END CATCH;
END;
GO

-- Inventario
CREATE OR ALTER PROCEDURE dbo.app_ConsultarInventario
    @IdUsuario INT,@Busqueda VARCHAR(100)='',@SoloBajoMinimo BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    SELECT IdInventario,NombreProducto,Descripcion,Cantidad,UnidadMedida,CantidadMinima,FechaActualizacion,Activo
    FROM dbo.Inventario
    WHERE (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(NombreProducto,' ',COALESCE(Descripcion,'')))>0)
      AND (@SoloBajoMinimo=0 OR (Activo=1 AND Cantidad<=CantidadMinima))
    ORDER BY NombreProducto;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarInventario
    @IdUsuario INT,@IdInventario INT=NULL,@NombreProducto VARCHAR(100),@Descripcion VARCHAR(250)='',
    @Cantidad DECIMAL(9,2),@UnidadMedida VARCHAR(20),@CantidadMinima DECIMAL(9,2)=0,@Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NULLIF(LTRIM(RTRIM(@NombreProducto)),'') IS NULL OR @UnidadMedida NOT IN ('Unidad','Gramo','Kilogramo','Mililitro','Litro')
       OR @Cantidad<0 OR @CantidadMinima<0
        THROW 50101,'Revisa el nombre, la unidad y las cantidades del producto.',1;
    IF EXISTS(SELECT 1 FROM dbo.Inventario WHERE NombreProducto=LTRIM(RTRIM(@NombreProducto)) AND (@IdInventario IS NULL OR IdInventario<>@IdInventario))
        THROW 50101,'Ya existe un producto con ese nombre.',1;
    IF @IdInventario IS NULL
    BEGIN
        INSERT dbo.Inventario(NombreProducto,Descripcion,Cantidad,UnidadMedida,CantidadMinima,Activo)
        VALUES(LTRIM(RTRIM(@NombreProducto)),@Descripcion,@Cantidad,@UnidadMedida,@CantidadMinima,@Activo);
        SET @IdInventario=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Inventario SET NombreProducto=LTRIM(RTRIM(@NombreProducto)),Descripcion=@Descripcion,Cantidad=@Cantidad,
            UnidadMedida=@UnidadMedida,CantidadMinima=@CantidadMinima,Activo=@Activo,FechaActualizacion=GETDATE()
        WHERE IdInventario=@IdInventario;
        IF @@ROWCOUNT=0 THROW 50104,'El producto no existe.',1;
    END;
    SELECT @IdInventario AS IdInventario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoInventario @IdUsuario INT,@IdInventario INT,@Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    UPDATE dbo.Inventario SET Activo=@Activo,FechaActualizacion=GETDATE() WHERE IdInventario=@IdInventario;
    IF @@ROWCOUNT=0 THROW 50104,'El producto no existe.',1;
    SELECT @IdInventario AS IdInventario,@Activo AS Activo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarInventario @IdUsuario INT,@IdInventario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Inventario WHERE IdInventario=@IdInventario)
        THROW 50104,'El producto no existe.',1;
    DELETE dbo.Inventario WHERE IdInventario=@IdInventario;
    SELECT @IdInventario AS IdInventario;
END;
GO

-- Promociones
CREATE OR ALTER PROCEDURE dbo.app_ConsultarPromociones
    @IdUsuario INT,@Busqueda VARCHAR(100)='',@IncluirInactivas BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    SELECT pr.IdPromocion,pr.IdServicio,ISNULL(s.NombreServicio,'') AS Servicio,pr.NombrePromocion,pr.Descripcion,
        pr.PorcentajeDescuento,pr.FechaInicio,pr.FechaFin,pr.Activa
    FROM dbo.Promociones pr LEFT JOIN dbo.Servicios s ON s.IdServicio=pr.IdServicio
    WHERE (pr.Activa=1 OR @IncluirInactivas=1)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,pr.NombrePromocion)>0)
    ORDER BY pr.FechaInicio DESC,pr.IdPromocion DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarPromocion
    @IdUsuario INT,@IdPromocion INT=NULL,@IdServicio INT=NULL,@NombrePromocion VARCHAR(100),
    @Descripcion VARCHAR(250)='',@PorcentajeDescuento DECIMAL(5,2),@FechaInicio DATE,@FechaFin DATE,@Activa BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NULLIF(LTRIM(RTRIM(@NombrePromocion)),'') IS NULL OR @PorcentajeDescuento<=0 OR @PorcentajeDescuento>100
       OR @FechaInicio IS NULL OR @FechaFin IS NULL OR @FechaFin<@FechaInicio
        THROW 50101,'Revisa el nombre, el porcentaje y las fechas de la promoción.',1;
    IF @IdServicio IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Servicios WHERE IdServicio=@IdServicio)
        THROW 50101,'El servicio indicado no existe.',1;
    IF @IdPromocion IS NULL
    BEGIN
        INSERT dbo.Promociones(IdServicio,NombrePromocion,Descripcion,PorcentajeDescuento,FechaInicio,FechaFin,Activa)
        VALUES(@IdServicio,LTRIM(RTRIM(@NombrePromocion)),@Descripcion,@PorcentajeDescuento,@FechaInicio,@FechaFin,@Activa);
        SET @IdPromocion=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Promociones SET IdServicio=@IdServicio,NombrePromocion=LTRIM(RTRIM(@NombrePromocion)),Descripcion=@Descripcion,
            PorcentajeDescuento=@PorcentajeDescuento,FechaInicio=@FechaInicio,FechaFin=@FechaFin,Activa=@Activa
        WHERE IdPromocion=@IdPromocion;
        IF @@ROWCOUNT=0 THROW 50104,'La promoción no existe.',1;
    END;
    SELECT @IdPromocion AS IdPromocion;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoPromocion @IdUsuario INT,@IdPromocion INT,@Activa BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    UPDATE dbo.Promociones SET Activa=@Activa WHERE IdPromocion=@IdPromocion;
    IF @@ROWCOUNT=0 THROW 50104,'La promoción no existe.',1;
    SELECT @IdPromocion AS IdPromocion,@Activa AS Activa;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarPromocion @IdUsuario INT,@IdPromocion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    if NOT EXISTS(SELECT 1 FROM dbo.Promociones WHERE IdPromocion=@IdPromocion)
        THROW 50104,'La promoción no existe.',1;
    DELETE dbo.Promociones WHERE IdPromocion=@IdPromocion;
    SELECT @IdPromocion AS IdPromocion;
END;
GO

-- Recolecciones
CREATE OR ALTER PROCEDURE dbo.app_ConsultarRecolecciones
    @IdUsuario INT,@Busqueda VARCHAR(100)='',@Estado VARCHAR(20)=''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    SELECT r.IdRecoleccion,r.IdPedido,r.Direccion,r.FechaProgramada,r.Estado,r.Observaciones,
        CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,c.Telefono
    FROM dbo.Recolecciones r JOIN dbo.Pedidos p ON p.IdPedido=r.IdPedido JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    WHERE (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(r.IdRecoleccion,r.IdPedido,c.Nombre,' ',c.Apellidos,' ',r.Direccion))>0)
      AND (@Estado='' OR r.Estado=@Estado)
    ORDER BY r.FechaProgramada DESC,r.IdRecoleccion DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarRecoleccion
    @IdUsuario INT,@IdRecoleccion INT=NULL,@IdPedido INT,@Direccion VARCHAR(250),
    @FechaProgramada DATETIME,@Estado VARCHAR(20)='Pendiente',@Observaciones VARCHAR(300)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @IdPedido IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Pedidos WHERE IdPedido=@IdPedido)
        THROW 50101,'Selecciona un pedido válido.',1;
    IF NULLIF(LTRIM(RTRIM(@Direccion)),'') IS NULL
        THROW 50101,'La dirección de recolección es obligatoria.',1;
    IF @Estado NOT IN ('Pendiente','Programada','Recolectada','Cancelada')
        THROW 50101,'El estado de la recolección no es válido.',1;
    IF @FechaProgramada IS NULL THROW 50101,'Indica la fecha programada.',1;
    if @IdRecoleccion IS NULL
    BEGIN
        INSERT dbo.Recolecciones(IdPedido,Direccion,FechaProgramada,Estado,Observaciones)
        VALUES(@IdPedido,LTRIM(RTRIM(@Direccion)),@FechaProgramada,@Estado,@Observaciones);
        SET @IdRecoleccion=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Recolecciones SET IdPedido=@IdPedido,Direccion=LTRIM(RTRIM(@Direccion)),FechaProgramada=@FechaProgramada,
            Estado=@Estado,Observaciones=@Observaciones WHERE IdRecoleccion=@IdRecoleccion;
        IF @@ROWCOUNT=0 THROW 50104,'La recolección no existe.',1;
    END;
    SELECT @IdRecoleccion AS IdRecoleccion;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoRecoleccion @IdUsuario INT,@IdRecoleccion INT,@Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @Estado NOT IN ('Pendiente','Programada','Recolectada','Cancelada')
        THROW 50101,'El estado de la recolección no es válido.',1;
    UPDATE dbo.Recolecciones SET Estado=@Estado WHERE IdRecoleccion=@IdRecoleccion;
    IF @@ROWCOUNT=0 THROW 50104,'La recolección no existe.',1;
    SELECT @IdRecoleccion AS IdRecoleccion,@Estado AS Estado;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarRecoleccion @IdUsuario INT,@IdRecoleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Recolecciones WHERE IdRecoleccion=@IdRecoleccion)
        THROW 50104,'La recolección no existe.',1;
    DELETE dbo.Recolecciones WHERE IdRecoleccion=@IdRecoleccion;
    SELECT @IdRecoleccion AS IdRecoleccion;
END;
GO

-- Pagos
CREATE OR ALTER PROCEDURE dbo.app_ConsultarPagos
    @IdUsuario INT,@IdPedido INT=NULL,@Estado VARCHAR(20)='',@Busqueda VARCHAR(100)=''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    DECLARE @Cliente INT=NULL;
    SELECT @Cliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente';
    SELECT pg.IdPago,pg.IdPedido,pg.FechaPago,pg.Monto,pg.MetodoPago,pg.EstadoPago,pg.Referencia,
        p.Total AS TotalPedido,p.Estado AS EstadoPedido,
        CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,c.Email
    FROM dbo.Pagos pg JOIN dbo.Pedidos p ON p.IdPedido=pg.IdPedido JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    WHERE (@Cliente IS NULL OR p.IdCliente=@Cliente)
      AND (@IdPedido IS NULL OR pg.IdPedido=@IdPedido)
      AND (@Estado='' OR pg.EstadoPago=@Estado)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(pg.IdPago,pg.IdPedido,c.Nombre,' ',c.Apellidos,' ',ISNULL(pg.Referencia,'')))>0)
    ORDER BY pg.FechaPago DESC,pg.IdPago DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarPago
    @IdUsuario INT,@IdPago INT=NULL,@IdPedido INT,@Monto DECIMAL(10,2),@MetodoPago VARCHAR(20),
    @EstadoPago VARCHAR(20)='Pendiente',@Referencia VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF @IdPedido IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Pedidos WHERE IdPedido=@IdPedido)
        THROW 50101,'Selecciona un pedido válido.',1;
    IF @Monto<=0 OR @Monto>(SELECT Total FROM dbo.Pedidos WHERE IdPedido=@IdPedido)
        THROW 50101,'El monto debe ser mayor que cero y no superar el total del pedido.',1;
    IF @MetodoPago NOT IN ('Efectivo','SINPE Movil')
        THROW 50101,'El método de pago no es válido.',1;
    IF @EstadoPago NOT IN ('Pendiente','Pagado','Anulado')
        THROW 50101,'El estado del pago no es válido.',1;
    IF @IdPago IS NOT NULL
    BEGIN
        EXEC dbo.app_ActualizarPagoSeguro @IdUsuario,@IdPago,@IdPedido,@Monto,@MetodoPago,@EstadoPago,@Referencia;
        RETURN;
    END;
    -- Alta: se registra el pago y se delega en el procedimiento seguro para validar
    -- el estado, encolar el comprobante y respetar la transición hacia 'Pagado'.
    DECLARE @Nuevo INT;
    INSERT dbo.Pagos(IdPedido,Monto,MetodoPago,EstadoPago,Referencia)
    VALUES(@IdPedido,@Monto,@MetodoPago,'Pendiente',@Referencia);
    SET @Nuevo=CONVERT(INT,SCOPE_IDENTITY());
    EXEC dbo.app_ActualizarPagoSeguro @IdUsuario,@Nuevo,@IdPedido,@Monto,@MetodoPago,@EstadoPago,@Referencia;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarPago @IdUsuario INT,@IdPago INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Pagos WHERE IdPago=@IdPago)
        THROW 50104,'El pago no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdPago=@IdPago)
        THROW 50101,'El pago tiene comprobantes asociados. Anúlalo en lugar de eliminarlo.',1;
    if EXISTS(SELECT 1 FROM dbo.Pagos WHERE IdPago=@IdPago AND EstadoPago='Pagado')
        THROW 50101,'Un pago pagado no se elimina; anúlalo para conservar el historial.',1;
    DELETE dbo.Pagos WHERE IdPago=@IdPago;
    SELECT @IdPago AS IdPago;
END;
GO

-- Borrado seguro de servicios (solo si no hay historial ni promociones asociadas).
CREATE OR ALTER PROCEDURE dbo.app_EliminarServicio @IdUsuario INT,@IdServicio INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Servicios WHERE IdServicio=@IdServicio)
        THROW 50104,'El servicio no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.DetallePedido WHERE IdServicio=@IdServicio)
        THROW 50101,'El servicio aparece en pedidos anteriores. Desactívalo para conservar el historial.',1;
    IF EXISTS(SELECT 1 FROM dbo.Promociones WHERE IdServicio=@IdServicio)
        THROW 50101,'El servicio tiene promociones asociadas. Elimínalas primero o desactiva el servicio.',1;
    DELETE dbo.Servicios WHERE IdServicio=@IdServicio;
    SELECT @IdServicio AS IdServicio;
END;
GO

-- Permisos: el login de la app necesita EXECUTE en los procedimientos nuevos.
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ramses_proyecto' AND type IN ('S','U','G'))
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.app_EmpresaPublica TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarEmpresa TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ServiciosPublicos TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarEmpleados TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarEmpleado TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CambiarEstadoEmpleado TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarEmpleado TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarUsuarios TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarUsuario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CambiarEstadoUsuario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarUsuario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarInventario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarInventario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CambiarEstadoInventario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarInventario TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarPromociones TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarPromocion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CambiarEstadoPromocion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarPromocion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarRecolecciones TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarRecoleccion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CambiarEstadoRecoleccion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarRecoleccion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConsultarPagos TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_GuardarPago TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarPago TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarServicio TO [ramses_proyecto];
END;
GO