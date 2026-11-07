-- ActualizaciÃƒÂ³n incremental: ejecutar en LavaFacil, en el servidor PRINCIPAL.
-- No restaura bases, no cambia roles de Mirroring y conserva los datos existentes.
USE [LavaFacil];
GO

IF OBJECT_ID(N'dbo.CorreoEnvios',N'U') IS NULL THROW 50110,'dbo.CorreoEnvios no existe.',1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CorreoEnvios') AND name=N'IX_CorreoEnvios_Pendientes') CREATE INDEX IX_CorreoEnvios_Pendientes ON dbo.CorreoEnvios(Estado,ProximoIntento) INCLUDE (ProcesandoHasta,Intentos);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CorreoEnvios') AND name=N'IX_CorreoEnvios_Lease') CREATE INDEX IX_CorreoEnvios_Lease ON dbo.CorreoEnvios(ProcesandoHasta) INCLUDE (Estado,ProximoIntento);
GO
-- Las definiciones ejecutables de la cola se mantienen idénticas en las cuatro entregas.
/* COLA_CORREO_IMPLEMENTACION_V1 */
GO
IF COL_LENGTH('dbo.Usuarios','ClaveHash') IS NULL
    ALTER TABLE dbo.Usuarios ADD ClaveHash VARCHAR(255) NULL;
IF COL_LENGTH('dbo.Usuarios','ClaveVersion') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios ADD ClaveVersion INT NOT NULL CONSTRAINT DF_Usuarios_ClaveVersion DEFAULT (0);
END
ELSE IF EXISTS(
    SELECT 1 FROM sys.columns c
    WHERE c.object_id=OBJECT_ID('dbo.Usuarios') AND c.name='ClaveVersion'
      AND (c.user_type_id<>TYPE_ID('int') OR c.is_nullable<>0)
)
    THROW 50110,'dbo.Usuarios.ClaveVersion existe pero no es INT NOT NULL.',1;
ELSE IF NOT EXISTS(
    SELECT 1
    FROM sys.default_constraints dc
    JOIN sys.columns c ON c.object_id=dc.parent_object_id AND c.column_id=dc.parent_column_id
    WHERE dc.parent_object_id=OBJECT_ID('dbo.Usuarios')
      AND c.name='ClaveVersion' AND dc.name='DF_Usuarios_ClaveVersion'
      AND REPLACE(REPLACE(REPLACE(REPLACE(LOWER(dc.definition),' ',''),'(',''),')',''),'0','0')='0'
)
    THROW 50110,'dbo.Usuarios.ClaveVersion no tiene el DEFAULT DF_Usuarios_ClaveVersion con valor 0.',1;
GO
IF OBJECT_ID('dbo.PerfilesApp','U') IS NULL
BEGIN
    CREATE TABLE dbo.PerfilesApp (
        IdUsuario INT NOT NULL PRIMARY KEY REFERENCES dbo.Usuarios(IdUsuario),
        Avatar VARCHAR(20) NOT NULL DEFAULT 'Iniciales',
        Tema VARCHAR(20) NOT NULL DEFAULT 'Oceano',
        Biografia NVARCHAR(200) NOT NULL DEFAULT N''
    );
END;
GO
-- ===== Cola transaccional de correo =====
IF OBJECT_ID(N'dbo.CorreoEnvios',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CorreoEnvios(
        IdEnvio BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CorreoEnvios PRIMARY KEY,
        Tipo VARCHAR(30) NOT NULL, ClaveUnica VARCHAR(180) NOT NULL CONSTRAINT UX_CorreoEnvios_ClaveUnica UNIQUE,
        IdPedido INT NULL, IdPago INT NULL, Destino VARCHAR(150) NOT NULL, Asunto VARCHAR(200) NOT NULL,
        DatosJson NVARCHAR(MAX) NOT NULL, Estado VARCHAR(20) NOT NULL CONSTRAINT DF_CorreoEnvios_Estado DEFAULT 'Pendiente',
        Intentos INT NOT NULL CONSTRAINT DF_CorreoEnvios_Intentos DEFAULT 0,
        ProximoIntento DATETIME2(0) NOT NULL CONSTRAINT DF_CorreoEnvios_ProximoIntento DEFAULT SYSUTCDATETIME(),
        ProcesandoHasta DATETIME2(0) NULL, TokenLease UNIQUEIDENTIFIER NULL,
        CreadoEn DATETIME2(0) NOT NULL CONSTRAINT DF_CorreoEnvios_CreadoEn DEFAULT SYSUTCDATETIME(),
        EnviadoEn DATETIME2(0) NULL, UltimoError VARCHAR(1000) NULL,
        CONSTRAINT FK_CorreoEnvios_Pedidos FOREIGN KEY(IdPedido) REFERENCES dbo.Pedidos(IdPedido),
        CONSTRAINT FK_CorreoEnvios_Pagos FOREIGN KEY(IdPago) REFERENCES dbo.Pagos(IdPago),
        CONSTRAINT CK_CorreoEnvios_Estado CHECK(Estado IN('Pendiente','Procesando','Enviado','Error'))
    );
END;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CorreoEnvios') AND name=N'IX_CorreoEnvios_Pendientes')
    CREATE INDEX IX_CorreoEnvios_Pendientes ON dbo.CorreoEnvios(Estado,ProximoIntento) INCLUDE(ProcesandoHasta,Intentos);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CorreoEnvios') AND name=N'IX_CorreoEnvios_Lease')
    CREATE INDEX IX_CorreoEnvios_Lease ON dbo.CorreoEnvios(ProcesandoHasta) INCLUDE(Estado,ProximoIntento);
GO
CREATE OR ALTER PROCEDURE dbo.app_ExigirAdministrador @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Administrador')
        THROW 50100,'Esta operaciÃƒÂ³n requiere una cuenta administradora.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_BuscarServicios @IdUsuario INT,@Busqueda VARCHAR(100)='',@IncluirInactivos BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @IncluirInactivos=1 EXEC dbo.app_ExigirAdministrador @IdUsuario;
    SELECT * FROM dbo.Servicios
    WHERE (Activo=1 OR @IncluirInactivos=1)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,NombreServicio)>0 OR CHARINDEX(@Busqueda,COALESCE(Descripcion,''))>0)
    ORDER BY NombreServicio;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarServicio
    @IdUsuario INT,@IdServicio INT=NULL,@NombreServicio VARCHAR(100),@Descripcion VARCHAR(250),
    @TipoCobro VARCHAR(20),@PrecioBase DECIMAL(10,2),@CantidadIncluida DECIMAL(10,2),@PrecioAdicional DECIMAL(10,2),@Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NULLIF(TRIM(@NombreServicio),'') IS NULL OR @TipoCobro NOT IN ('Kilogramo','Unidad','Uniforme')
       OR @PrecioBase<0 OR @CantidadIncluida<=0 OR @PrecioAdicional<0
        THROW 50101,'Revisa el nombre, tipo de cobro y los importes del servicio.',1;
    IF @IdServicio IS NULL
    BEGIN
        INSERT dbo.Servicios(NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,PrecioAdicional,Activo)
        VALUES(TRIM(@NombreServicio),@Descripcion,@TipoCobro,@PrecioBase,@CantidadIncluida,@PrecioAdicional,@Activo);
        SET @IdServicio=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Servicios SET NombreServicio=TRIM(@NombreServicio),Descripcion=@Descripcion,TipoCobro=@TipoCobro,
            PrecioBase=@PrecioBase,CantidadIncluida=@CantidadIncluida,PrecioAdicional=@PrecioAdicional,Activo=@Activo
        WHERE IdServicio=@IdServicio;
        IF @@ROWCOUNT=0 THROW 50104,'El servicio no existe.',1;
    END;
    SELECT @IdServicio AS IdServicio;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearPedido
    @IdUsuario INT,@IdCliente INT=NULL,@Observaciones VARCHAR(300)='',@Lineas NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente')
        SELECT @IdCliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente AND Activo=1)
        THROW 50101,'Selecciona un cliente activo.',1;
    IF ISJSON(@Lineas)<>1 THROW 50101,'El detalle del pedido no es vÃƒÂ¡lido.',1;
    DECLARE @Detalle TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2));
    IF EXISTS(SELECT IdServicio FROM OPENJSON(@Lineas) WITH(IdServicio INT '$.serviceId') GROUP BY IdServicio HAVING COUNT(*)>1)
        THROW 50101,'Cada servicio debe aparecer una sola vez; ajusta su cantidad.',1;
    INSERT @Detalle SELECT IdServicio,Cantidad FROM OPENJSON(@Lineas)
        WITH(IdServicio INT '$.serviceId',Cantidad DECIMAL(10,2) '$.quantity');
    IF (SELECT COUNT(*) FROM @Detalle) NOT BETWEEN 1 AND 30 OR EXISTS(SELECT 1 FROM @Detalle WHERE Cantidad IS NULL OR Cantidad<=0 OR Cantidad>10000)
        THROW 50101,'Agrega de 1 a 30 servicios con cantidades positivas (mÃƒÂ¡ximo 10000).',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Bloquea las tarifas seleccionadas hasta terminar el registro completo.
        DECLARE @Tarifas TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2),Base DECIMAL(10,2),Adicional DECIMAL(18,2));
        INSERT @Tarifas
        SELECT d.IdServicio,d.Cantidad,s.PrecioBase,
            CASE WHEN d.Cantidad>s.CantidadIncluida THEN (d.Cantidad-s.CantidadIncluida)*COALESCE(s.PrecioAdicional,0) ELSE 0 END
        FROM @Detalle d JOIN dbo.Servicios s WITH(UPDLOCK,HOLDLOCK) ON s.IdServicio=d.IdServicio AND s.Activo=1;
        IF (SELECT COUNT(*) FROM @Tarifas)<>(SELECT COUNT(*) FROM @Detalle)
            THROW 50101,'Uno de los servicios no existe o estÃƒÂ¡ inactivo. Actualiza el catÃƒÂ¡logo.',1;
        IF EXISTS(SELECT 1 FROM @Detalle d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio WHERE s.TipoCobro<>'Kilogramo' AND d.Cantidad<>FLOOR(d.Cantidad))
            THROW 50101,'Las unidades y los uniformes requieren cantidades enteras.',1;
        IF (SELECT SUM(Base+Adicional) FROM @Tarifas)>99999999.99
            THROW 50101,'El total supera el mÃƒÂ¡ximo permitido.',1;
        INSERT dbo.Pedidos(IdCliente,Estado,Total,Observaciones) VALUES(@IdCliente,'Pendiente',0,@Observaciones);
   DECLARE @IdPedido INT=CONVERT(INT,SCOPE_IDENTITY());
   INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal)
   SELECT @IdPedido,IdServicio,Cantidad,Base,Adicional,Base+Adicional FROM @Tarifas;
   UPDATE dbo.Pedidos SET Total=COALESCE((SELECT SUM(Subtotal) FROM dbo.DetallePedido WHERE IdPedido=@IdPedido),0) WHERE IdPedido=@IdPedido;
        COMMIT;
        SELECT IdPedido,Total,Estado FROM dbo.Pedidos WHERE IdPedido=@IdPedido;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_BuscarPedidos
    @IdUsuario INT,@Desde DATE=NULL,@Hasta DATE=NULL,@Estado VARCHAR(20)='',@Busqueda VARCHAR(100)='',@IdServicio INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @Desde>@Hasta THROW 50101,'La fecha inicial no puede ser posterior a la final.',1;
    DECLARE @Cliente INT=NULL;
    SELECT @Cliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente';
    SELECT TOP (500) p.IdPedido,p.FechaPedido,p.FechaEntregaEstimada,p.Estado,p.Total,p.Observaciones,
        c.IdCliente,CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,c.Cedula,
        (SELECT COUNT(*) FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido) AS Servicios
    FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    WHERE (@Cliente IS NULL OR p.IdCliente=@Cliente)
      AND (@Desde IS NULL OR CAST(p.FechaPedido AS DATE)>=@Desde)
      AND (@Hasta IS NULL OR CAST(p.FechaPedido AS DATE)<=@Hasta)
      AND (@Estado='' OR p.Estado=@Estado)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(c.Nombre,' ',c.Apellidos,' ',c.Cedula,' ',p.IdPedido))>0)
      AND (@IdServicio IS NULL OR EXISTS(SELECT 1 FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido AND d.IdServicio=@IdServicio))
    ORDER BY p.FechaPedido DESC,p.IdPedido DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_DetallePedido @IdUsuario INT,@IdPedido INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Pedidos p CROSS JOIN dbo.Usuarios u
        WHERE p.IdPedido=@IdPedido AND u.IdUsuario=@IdUsuario AND (u.TipoUsuario<>'Cliente' OR p.IdCliente=u.IdCliente))
        THROW 50104,'El pedido no existe o no estÃƒÂ¡ disponible para tu cuenta.',1;
    SELECT p.IdPedido,p.Estado,p.Total,p.FechaPedido,p.Observaciones,CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,
        d.IdServicio,s.NombreServicio,s.TipoCobro,d.Cantidad,d.PrecioBase,d.MontoAdicional,d.Subtotal
    FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    JOIN dbo.DetallePedido d ON d.IdPedido=p.IdPedido JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio
    WHERE p.IdPedido=@IdPedido ORDER BY d.IdDetalle;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoPedido @IdUsuario INT,@IdPedido INT,@Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @Estado NOT IN ('Pendiente','Recibido','En proceso','Listo','Entregado','Cancelado')
        THROW 50101,'Estado de pedido inv?lido.',1;

    DECLARE @Anterior VARCHAR(20),@Total DECIMAL(10,2),@IdCliente INT,
            @Nombre VARCHAR(50),@Apellidos VARCHAR(100),@Email VARCHAR(150),
            @Clave VARCHAR(180),@Json NVARCHAR(MAX);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @Anterior=p.Estado,@Total=p.Total,@IdCliente=p.IdCliente,
               @Nombre=c.Nombre,@Apellidos=c.Apellidos,@Email=NULLIF(TRIM(c.Email),'')
        FROM dbo.Pedidos p WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
        WHERE p.IdPedido=@IdPedido;
        IF @Anterior IS NULL THROW 50104,'El pedido no existe.',1;

        IF @Anterior=@Estado
        BEGIN
            COMMIT;
            SELECT @IdPedido AS IdPedido,@Estado AS Estado;
            RETURN;
        END;
        IF @Anterior IN ('Entregado','Cancelado')
            THROW 50101,'El estado actual del pedido es terminal.',1;
        IF NOT ((@Anterior='Pendiente' AND @Estado IN ('Recibido','Cancelado'))
             OR (@Anterior='Recibido' AND @Estado IN ('En proceso','Cancelado'))
             OR (@Anterior='En proceso' AND @Estado IN ('Listo','Cancelado'))
             OR (@Anterior='Listo' AND @Estado IN ('Entregado','Cancelado')))
            THROW 50101,'La transici?n de estado del pedido no es v?lida.',1;

        UPDATE dbo.Pedidos SET Estado=@Estado WHERE IdPedido=@IdPedido;
        IF @Email IS NOT NULL
        BEGIN
            SET @Clave=CONCAT('pedido:',@IdPedido,':estado:',@Anterior,':',@Estado);
            SET @Json=(SELECT @IdPedido AS IdPedido,@Anterior AS EstadoAnterior,@Estado AS EstadoNuevo,
                              @Total AS Total,@Nombre AS Nombre,@Apellidos AS Apellidos,@Email AS Email,
                              JSON_QUERY((SELECT s.NombreServicio,d.Cantidad,d.Subtotal
                                          FROM dbo.DetallePedido d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio
                                          WHERE d.IdPedido=@IdPedido ORDER BY d.IdDetalle FOR JSON PATH)) AS Detalle
                       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
            IF NOT EXISTS(SELECT 1 FROM dbo.CorreoEnvios WITH(UPDLOCK,HOLDLOCK) WHERE ClaveUnica=@Clave)
                INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,IdPedido,Destino,Asunto,DatosJson)
                VALUES('PedidoEstado',@Clave,@IdPedido,@Email,CONCAT('Estado del pedido #',@IdPedido,': ',@Estado),@Json);
        END;
        COMMIT;
        SELECT @IdPedido AS IdPedido,@Estado AS Estado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_Preferencias @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT COALESCE(p.Avatar,'Iniciales') AS Avatar,COALESCE(p.Tema,'Oceano') AS Tema,
        COALESCE(p.Biografia,N'') AS Biografia,c.Direccion
    FROM dbo.Usuarios u LEFT JOIN dbo.PerfilesApp p ON p.IdUsuario=u.IdUsuario
    LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente WHERE u.IdUsuario=@IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarPreferencias
    @IdUsuario INT,@Avatar VARCHAR(20),@Tema VARCHAR(20),@Biografia NVARCHAR(200),@Direccion VARCHAR(250)=''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @Avatar NOT IN ('Iniciales','Burbuja','Gota','Camisa','Flor') OR @Tema NOT IN ('Oceano','Bosque','Violeta')
        THROW 50101,'Selecciona un avatar y tema vÃƒÂ¡lidos.',1;
    BEGIN TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.PerfilesApp WITH(UPDLOCK,HOLDLOCK) WHERE IdUsuario=@IdUsuario)
        UPDATE dbo.PerfilesApp SET Avatar=@Avatar,Tema=@Tema,Biografia=@Biografia WHERE IdUsuario=@IdUsuario;
    ELSE INSERT dbo.PerfilesApp(IdUsuario,Avatar,Tema,Biografia) VALUES(@IdUsuario,@Avatar,@Tema,@Biografia);
    UPDATE c SET Direccion=@Direccion FROM dbo.Clientes c JOIN dbo.Usuarios u ON u.IdCliente=c.IdCliente WHERE u.IdUsuario=@IdUsuario;
    COMMIT;
    EXEC dbo.app_Preferencias @IdUsuario;
END;
GO
-- Hash PBKDF2 calculado y verificado por el backend. Nunca se devuelve al navegador.
CREATE OR ALTER PROCEDURE dbo.app_Credencial @NombreUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario,u.NombreUsuario,u.TipoUsuario,u.ClaveVersion,u.ClaveHash
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.NombreUsuario=@NombreUsuario AND u.Activo=1
      AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Administrador','Empleado') AND e.Activo=1));
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarClave @IdUsuario INT,@Hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    UPDATE dbo.Usuarios SET ClaveHash=@Hash,Clave=CONVERT(VARCHAR(255),NEWID()),ClaveVersion=ClaveVersion+1 WHERE IdUsuario=@IdUsuario;
    SELECT @IdUsuario AS IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearCuentaCliente @IdUsuario INT,@IdCliente INT,@NombreUsuario VARCHAR(50),@Hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE IdCliente=@IdCliente AND Activo=1)
            THROW 50101,'El cliente no existe o estÃƒÂ¡ inactivo.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE IdCliente=@IdCliente)
            THROW 50101,'Este cliente ya tiene una cuenta.',1;
        INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdCliente)
        VALUES(@NombreUsuario,CONVERT(VARCHAR(255),NEWID()),@Hash,'Cliente',@IdCliente);
        DECLARE @Creado INT=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT;
        SELECT @Creado AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ActualizarCliente
    @IdUsuario INT,@IdCliente INT,@Cedula VARCHAR(20),@Nombre VARCHAR(50),@Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),@Email VARCHAR(150),@Direccion VARCHAR(250)=''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NULLIF(TRIM(@Cedula),'') IS NULL OR NULLIF(TRIM(@Nombre),'') IS NULL OR NULLIF(TRIM(@Apellidos),'') IS NULL
       OR NULLIF(TRIM(@Telefono),'') IS NULL OR NULLIF(TRIM(@Email),'') IS NULL
        THROW 50101,'Completa los datos obligatorios del cliente.',1;
    UPDATE dbo.Clientes SET Cedula=TRIM(@Cedula),Nombre=TRIM(@Nombre),Apellidos=TRIM(@Apellidos),
        Telefono=TRIM(@Telefono),Email=TRIM(@Email),Direccion=@Direccion
    WHERE IdCliente=@IdCliente;
    IF @@ROWCOUNT=0 THROW 50104,'El cliente no existe.',1;
    SELECT IdCliente,Cedula,Nombre,Apellidos,Telefono,Email,Direccion,FechaRegistro,Activo
    FROM dbo.Clientes WHERE IdCliente=@IdCliente;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoCliente @IdUsuario INT,@IdCliente INT,@Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    BEGIN TRANSACTION;
    UPDATE dbo.Clientes SET Activo=@Activo WHERE IdCliente=@IdCliente;
    IF @@ROWCOUNT=0
    BEGIN
        ROLLBACK;
        THROW 50104,'El cliente no existe.',1;
    END;
    -- Una cuenta de cliente no puede quedar activa si su perfil fue desactivado.
    IF @Activo=0 UPDATE dbo.Usuarios SET Activo=0 WHERE IdCliente=@IdCliente;
    COMMIT;
    SELECT @IdCliente AS IdCliente,@Activo AS Activo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarClienteSeguro @IdUsuario INT,@IdCliente INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente)
        THROW 50104,'El cliente no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.Pedidos WHERE IdCliente=@IdCliente)
        THROW 50101,'El cliente tiene pedidos relacionados. DesactÃƒÂ­valo para conservar su historial.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdCliente=@IdCliente)
        THROW 50101,'El cliente tiene una cuenta de acceso. DesactÃƒÂ­valo para conservar su historial.',1;
    DELETE dbo.Clientes WHERE IdCliente=@IdCliente;
    SELECT @IdCliente AS IdCliente;
END;
GO
-- Auto-registro pÃƒÂºblico de clientes: es anÃƒÂ³nimo, por eso no llama app_Autorizar ni app_ExigirAdministrador.
-- La contraseÃƒÂ±a viaja solo como hash PBKDF2 calculado por el backend; jamÃƒÂ¡s se acepta texto plano.
CREATE OR ALTER PROCEDURE dbo.app_AutoRegistroCliente
    @Cedula VARCHAR(20), @Nombre VARCHAR(50), @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(150), @Direccion VARCHAR(250)=NULL,
    @NombreUsuario VARCHAR(50), @Hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@NombreUsuario)),'') IS NULL
        THROW 50101,'Completa todos los datos obligatorios del cliente.',1;
    IF NULLIF(LTRIM(RTRIM(@Hash)),'') IS NULL OR LEFT(@Hash,14)<>'PBKDF2-SHA256$'
        THROW 50101,'No se pudo preparar la contraseÃƒÂ±a para guardarla.',1;
    DECLARE @IdCliente INT=NULL,@IdUsuario INT=NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Guard de bootstrap: el auto-registro no puede crear el primer usuario si aÃƒÂºn no hay administrador.
        -- TABLOCKX+HOLDLOCK mantiene la comprobaciÃƒÂ³n atÃƒÂ³mica frente a la creaciÃƒÂ³n inicial del administrador.
        IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WITH(TABLOCKX,HOLDLOCK))
            THROW 50102,'La creaciÃƒÂ³n inicial de la cuenta de administrador estÃƒÂ¡ pendiente. Configura primero el administrador.',1;
        -- UPDLOCK+HOLDLOCK serializa los pre-chequeos; un ÃƒÂºnico mensaje genÃƒÂ©rico evita enumerar quÃƒÂ© dato ya existe.
        IF EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE Cedula=TRIM(@Cedula))
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesiÃƒÂ³n o contacta al administrador.',1;
        IF EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE Email=TRIM(@Email))
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesiÃƒÂ³n o contacta al administrador.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE NombreUsuario=TRIM(@NombreUsuario) AND Activo=1)
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesiÃƒÂ³n o contacta al administrador.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE NombreUsuario=TRIM(@NombreUsuario) AND Activo=0)
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesiÃƒÂ³n o contacta al administrador.',1;
        -- Siempre se crea un cliente nuevo; nunca se enlaza a un IdCliente existente (evita robo de cuenta).
        INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email,Direccion,Activo)
        VALUES(TRIM(@Cedula),TRIM(@Nombre),TRIM(@Apellidos),TRIM(@Telefono),TRIM(@Email),NULLIF(TRIM(@Direccion),''),1);
        SET @IdCliente=CONVERT(INT,SCOPE_IDENTITY());
        -- Mismo patrÃƒÂ³n que app_CrearCuentaCliente: Clave recibe un valor aleatorio y el hash va en ClaveHash.
        INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdCliente,Activo)
        VALUES(TRIM(@NombreUsuario),CONVERT(VARCHAR(255),NEWID()),@Hash,'Cliente',@IdCliente,1);
        SET @IdUsuario=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdUsuario AS IdUsuario,@IdCliente AS IdCliente;
END;
GO
-- ===== Correo del aplicativo: verificaciÃƒÂ³n de email y recuperaciÃƒÂ³n de contraseÃƒÂ±a =====
-- El cÃƒÂ³digo de 6 dÃƒÂ­gitos nunca se guarda en claro: solo su hash SHA-256 (VARBINARY(32)).
-- app_SolicitarRecuperacion y app_RestablecerClave son pÃƒÂºblicos: no llaman app_Autorizar.
IF COL_LENGTH('dbo.Usuarios','EmailVerificado') IS NULL
    ALTER TABLE dbo.Usuarios ADD EmailVerificado VARCHAR(150) NULL;
IF COL_LENGTH('dbo.Usuarios','EmailVerificadoEn') IS NULL
    ALTER TABLE dbo.Usuarios ADD EmailVerificadoEn DATETIME2(0) NULL;
GO
IF OBJECT_ID('dbo.TokensCorreo','U') IS NULL
BEGIN
    CREATE TABLE dbo.TokensCorreo (
        IdToken INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TokensCorreo PRIMARY KEY,
        IdUsuario INT NOT NULL CONSTRAINT FK_TokensCorreo_Usuarios REFERENCES dbo.Usuarios(IdUsuario),
        Proposito VARCHAR(20) NOT NULL,
        CodigoHash VARBINARY(32) NOT NULL,
        EmailDestino VARCHAR(150) NOT NULL,
        CreadoEn DATETIME2(0) NOT NULL CONSTRAINT DF_TokensCorreo_CreadoEn DEFAULT SYSUTCDATETIME(),
        ExpiraEn DATETIME2(0) NOT NULL,
        Intentos TINYINT NOT NULL CONSTRAINT DF_TokensCorreo_Intentos DEFAULT 0,
        UsadoEn DATETIME2(0) NULL,
        CONSTRAINT CK_TokensCorreo_Proposito CHECK (Proposito IN ('Verificacion','Recuperacion')),
        CONSTRAINT CK_TokensCorreo_Intentos CHECK (Intentos BETWEEN 0 AND 10)
    );
END;
GO
IF OBJECT_ID('dbo.TokensCorreo','U') IS NULL
    THROW 50110,'dbo.TokensCorreo no existe; no se pueden crear sus ÃƒÂ­ndices.',1;
IF EXISTS(
    SELECT 1 FROM (VALUES
        ('IdToken','int',4,0,0,0),('IdUsuario','int',4,0,0,0),('Proposito','varchar',20,0,0,0),
        ('CodigoHash','varbinary',32,0,0,0),('EmailDestino','varchar',150,0,0,0),('CreadoEn','datetime2',6,0,0,0),
        ('ExpiraEn','datetime2',6,0,0,0),('Intentos','tinyint',1,0,0,0),('UsadoEn','datetime2',6,0,0,1)
    ) v(Nombre,Tipo,Longitud,Prec,Scale,Nullable)
    LEFT JOIN sys.columns c ON c.object_id=OBJECT_ID('dbo.TokensCorreo') AND c.name=v.Nombre
    WHERE c.column_id IS NULL OR TYPE_NAME(c.user_type_id)<>v.Tipo OR c.max_length<>v.Longitud
       OR c.scale<>v.Scale OR c.is_nullable<>v.Nullable
)
    THROW 50110,'dbo.TokensCorreo existe pero le faltan columnas o tiene una definiciÃƒÂ³n incompatible.',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID('dbo.TokensCorreo') AND name='PK_TokensCorreo')
    OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk
        WHERE fk.parent_object_id=OBJECT_ID('dbo.TokensCorreo') AND fk.name='FK_TokensCorreo_Usuarios'
          AND fk.referenced_object_id=OBJECT_ID('dbo.Usuarios')
          AND (SELECT COUNT(*) FROM sys.foreign_key_columns fkc WHERE fkc.constraint_object_id=fk.object_id)=1
          AND EXISTS(SELECT 1 FROM sys.foreign_key_columns fkc
              JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
              JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
              WHERE fkc.constraint_object_id=fk.object_id AND pc.name='IdUsuario' AND rc.name='IdUsuario'))
   OR NOT EXISTS(SELECT 1 FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID('dbo.TokensCorreo') AND name IN ('DF_TokensCorreo_CreadoEn','DF_TokensCorreo_Intentos'))
    OR NOT EXISTS(SELECT 1 FROM sys.check_constraints cc WHERE cc.parent_object_id=OBJECT_ID('dbo.TokensCorreo') AND cc.name='CK_TokensCorreo_Proposito'
        AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(cc.definition),' ',''),'(',''),')',''),'[',''),']','') IN
            ('proposito=''verificacion''orproposito=''recuperacion''','proposito=''recuperacion''orproposito=''verificacion''','propositoin''verificacion'',''recuperacion'''))
    OR NOT EXISTS(SELECT 1 FROM sys.check_constraints cc WHERE cc.parent_object_id=OBJECT_ID('dbo.TokensCorreo') AND cc.name='CK_TokensCorreo_Intentos'
        AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(cc.definition),' ',''),'(',''),')',''),'[',''),']','') IN
            ('intentosbetween0and10','intentos>=0andintentos<=10'))
    THROW 50110,'dbo.TokensCorreo existe pero le faltan constraints requeridas.',1;
IF EXISTS(
    SELECT 1 FROM sys.indexes i
    WHERE i.object_id=OBJECT_ID('dbo.TokensCorreo') AND i.name='UX_TokensCorreo_Activo'
       AND (i.is_unique<>1 OR i.type<>2 OR i.has_filter<>1
        OR (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)<>2
       OR NOT EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name='IdUsuario')
       OR NOT EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND c.name='Proposito')
       OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(i.filter_definition),' ',''),'(',''),')',''),'[',''),']','')<>'usadoenisnull')
)
    THROW 50110,'UX_TokensCorreo_Activo existe con una definiciÃƒÂ³n incompatible.',1;
IF EXISTS(
    SELECT 1 FROM sys.indexes i
    WHERE i.object_id=OBJECT_ID('dbo.TokensCorreo') AND i.name='IX_TokensCorreo_Limpieza'
      AND (i.is_unique<>0 OR i.type<>2
       OR NOT EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name='ExpiraEn')
       OR NOT EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.is_included_column=1 AND c.name='UsadoEn')
      )
)
    THROW 50110,'IX_TokensCorreo_Limpieza existe con una definiciÃƒÂ³n incompatible.',1;
-- Los ÃƒÂ­ndices filtrados exigen estas opciones de sesiÃƒÂ³n al crearse (SqlClient deja ARITHABORT en OFF).
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
-- Un solo token vigente por usuario y propÃƒÂ³sito: el ÃƒÂ­ndice filtrado lo garantiza.
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TokensCorreo') AND name='UX_TokensCorreo_Activo')
    CREATE UNIQUE INDEX UX_TokensCorreo_Activo ON dbo.TokensCorreo(IdUsuario,Proposito) WHERE UsadoEn IS NULL;
GO
-- Apoya la limpieza acotada de tokens vencidos.
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TokensCorreo') AND name='IX_TokensCorreo_Limpieza')
    CREATE INDEX IX_TokensCorreo_Limpieza ON dbo.TokensCorreo(ExpiraEn) INCLUDE(UsadoEn);
GO
CREATE OR ALTER PROCEDURE dbo.app_CorreoEstado @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    DECLARE @Email VARCHAR(150)=NULL,@Verificado BIT=0,@VerificadoEn DATETIME2(0)=NULL;
    SELECT @Email=COALESCE(c.Email,e.Email),
        @Verificado=CONVERT(BIT,CASE WHEN u.EmailVerificado IS NOT NULL AND u.EmailVerificado=COALESCE(c.Email,e.Email) THEN 1 ELSE 0 END),
        @VerificadoEn=u.EmailVerificadoEn
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.IdUsuario=@IdUsuario;
    -- Token activo = no usado; el ÃƒÂ­ndice filtrado mantiene uno solo por propÃƒÂ³sito.
    DECLARE @TienePendiente BIT=0,@ExpiraEn DATETIME2(0)=NULL,@IntentosRestantes TINYINT=0;
    SELECT TOP (1) @ExpiraEn=t.ExpiraEn,
        @IntentosRestantes=CONVERT(TINYINT,CASE WHEN t.Intentos>=5 THEN 0 ELSE 5-CONVERT(INT,t.Intentos) END)
    FROM dbo.TokensCorreo t
    WHERE t.IdUsuario=@IdUsuario AND t.Proposito='Verificacion' AND t.UsadoEn IS NULL
    ORDER BY t.IdToken DESC;
    IF @ExpiraEn IS NOT NULL SET @TienePendiente=1;
    DECLARE @UltimoEnvio DATETIME2(0)=NULL;
    SELECT @UltimoEnvio=MAX(t.CreadoEn) FROM dbo.TokensCorreo t
    WHERE t.IdUsuario=@IdUsuario AND t.Proposito='Verificacion';
    DECLARE @SegundosEspera INT=0;
    IF @UltimoEnvio IS NOT NULL SET @SegundosEspera=60-DATEDIFF(SECOND,@UltimoEnvio,SYSUTCDATETIME());
    IF @SegundosEspera<0 SET @SegundosEspera=0;
    IF @SegundosEspera>60 SET @SegundosEspera=60;
    SELECT @Email AS Email,@Verificado AS Verificado,@VerificadoEn AS VerificadoEn,
        @TienePendiente AS TienePendiente,@ExpiraEn AS ExpiraEn,
        @SegundosEspera AS SegundosEspera,@IntentosRestantes AS IntentosRestantes;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearTokenCorreo
    @IdUsuario INT,@Proposito VARCHAR(20),@CodigoHash VARBINARY(32),@MinutosValidez INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @Proposito IS NULL OR @Proposito NOT IN ('Verificacion','Recuperacion')
       OR @CodigoHash IS NULL OR DATALENGTH(@CodigoHash)<>32
       OR @MinutosValidez IS NULL OR @MinutosValidez NOT BETWEEN 1 AND 60
        THROW 50110,'Los datos del cÃƒÂ³digo de correo no son vÃƒÂ¡lidos.',1;
    DECLARE @Email VARCHAR(150)=NULL;
    SELECT @Email=COALESCE(c.Email,e.Email)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.IdUsuario=@IdUsuario;
    IF @Email IS NULL
        THROW 50111,'Tu cuenta no tiene un correo registrado. Actualiza tu perfil para continuar.',1;
    DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME();
    DECLARE @ExpiraEn DATETIME2(0)=DATEADD(MINUTE,@MinutosValidez,@Ahora);
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @LockResult INT;
        DECLARE @RecursoBloqueo NVARCHAR(255)=N'LavaFacil:TokensCorreo:Usuario:'+CONVERT(NVARCHAR(20),@IdUsuario);
        EXEC @LockResult=sp_getapplock
            @Resource=@RecursoBloqueo,
            @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
        IF @LockResult<>0
            THROW 50110,'No se pudo reservar el control de envÃƒÂ­os de correo.',1;
        IF (SELECT COUNT(*) FROM dbo.TokensCorreo
            WHERE IdUsuario=@IdUsuario AND CreadoEn>=DATEADD(HOUR,-24,SYSUTCDATETIME()))>=10
            THROW 50120,'Alcanzaste el lÃƒÂ­mite de envÃƒÂ­os de correo. Intenta de nuevo mÃƒÂ¡s tarde.',1;
        -- Limpieza acotada: nunca toca tokens vigentes ni recientes.
        DELETE TOP (200) FROM dbo.TokensCorreo
        WHERE ExpiraEn<DATEADD(DAY,-7,SYSUTCDATETIME());
        -- Un ÃƒÂºnico token vigente por propÃƒÂ³sito: el anterior se marca como usado.
        UPDATE t SET t.UsadoEn=@Ahora
        FROM dbo.TokensCorreo t WITH(UPDLOCK,HOLDLOCK)
        WHERE t.IdUsuario=@IdUsuario AND t.Proposito=@Proposito AND t.UsadoEn IS NULL;
        INSERT dbo.TokensCorreo(IdUsuario,Proposito,CodigoHash,EmailDestino,CreadoEn,ExpiraEn,Intentos)
        VALUES(@IdUsuario,@Proposito,@CodigoHash,@Email,@Ahora,@ExpiraEn,0);
        DECLARE @IdToken INT=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdToken AS IdToken,@Email AS EmailDestino,@ExpiraEn AS ExpiraEn;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_SolicitarRecuperacion
    @Identificador VARCHAR(150),@CodigoHash VARBINARY(32),@MinutosValidez INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Identificador=NULLIF(LTRIM(RTRIM(@Identificador)),'');
    IF @Identificador IS NULL OR @CodigoHash IS NULL OR DATALENGTH(@CodigoHash)<>32
       OR @MinutosValidez IS NULL OR @MinutosValidez NOT BETWEEN 1 AND 60
        THROW 50110,'Los datos del cÃƒÂ³digo de correo no son vÃƒÂ¡lidos.',1;
    DECLARE @IdUsuario INT=NULL,@Coincidencias INT=0,@Email VARCHAR(150)=NULL,@Nombre VARCHAR(50)=NULL;
    -- ResoluciÃƒÂ³n silenciosa por nombre de usuario: solo cuentas y dueÃƒÂ±os activos.
    SELECT @IdUsuario=MIN(u.IdUsuario),@Coincidencias=COUNT(*)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.NombreUsuario=@Identificador AND u.Activo=1
      AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1));
    IF @Coincidencias<>1 SET @IdUsuario=NULL;
    IF @IdUsuario IS NULL
    BEGIN
        -- Si el identificador no es un nombre de usuario, se intenta por correo.
        SET @Coincidencias=0;
        SELECT @IdUsuario=MIN(u.IdUsuario),@Coincidencias=COUNT(*)
        FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE (c.Email=@Identificador OR e.Email=@Identificador) AND u.Activo=1
          AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1));
        IF @Coincidencias<>1 SET @IdUsuario=NULL;
    END;
    -- Sin coincidencia ÃƒÂºnica se devuelven 0 filas: no se revela si la cuenta existe.
    IF @IdUsuario IS NULL RETURN;
    SELECT @Email=COALESCE(c.Email,e.Email),@Nombre=COALESCE(c.Nombre,e.Nombre)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.IdUsuario=@IdUsuario;
    IF @Email IS NULL RETURN;
    DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME();
    DECLARE @ExpiraEn DATETIME2(0)=DATEADD(MINUTE,@MinutosValidez,@Ahora);
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @LockResult INT;
        DECLARE @RecursoBloqueo NVARCHAR(255)=N'LavaFacil:TokensCorreo:Usuario:'+CONVERT(NVARCHAR(20),@IdUsuario);
        EXEC @LockResult=sp_getapplock
            @Resource=@RecursoBloqueo,
            @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
        IF @LockResult<>0
        BEGIN
            ROLLBACK;
            RETURN;
        END;
        IF (SELECT COUNT(*) FROM dbo.TokensCorreo
            WHERE IdUsuario=@IdUsuario AND CreadoEn>=DATEADD(HOUR,-24,SYSUTCDATETIME()))>=10
        BEGIN
            ROLLBACK;
            RETURN;
        END;
        UPDATE t SET t.UsadoEn=@Ahora
        FROM dbo.TokensCorreo t WITH(UPDLOCK,HOLDLOCK)
        WHERE t.IdUsuario=@IdUsuario AND t.Proposito='Recuperacion' AND t.UsadoEn IS NULL;
        INSERT dbo.TokensCorreo(IdUsuario,Proposito,CodigoHash,EmailDestino,CreadoEn,ExpiraEn,Intentos)
        VALUES(@IdUsuario,'Recuperacion',@CodigoHash,@Email,@Ahora,@ExpiraEn,0);
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdUsuario AS IdUsuario,@Email AS EmailDestino,@Nombre AS Nombre;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ConfirmarCorreo
    @IdUsuario INT,@CodigoHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @CodigoHash IS NULL OR DATALENGTH(@CodigoHash)<>32
        THROW 50110,'Los datos del cÃƒÂ³digo de correo no son vÃƒÂ¡lidos.',1;
    DECLARE @IdToken INT=NULL,@HashGuardado VARBINARY(32)=NULL,@ExpiraEn DATETIME2(0)=NULL,
        @Intentos TINYINT=0,@EmailDestino VARCHAR(150)=NULL,@EmailActual VARCHAR(150)=NULL;
    DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME();
    DECLARE @MensajeCodigo NVARCHAR(2048)=N'El cÃƒÂ³digo no es vÃƒÂ¡lido o ya venciÃƒÂ³. Solicita uno nuevo.';
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT TOP (1) @IdToken=t.IdToken,@HashGuardado=t.CodigoHash,@ExpiraEn=t.ExpiraEn,
            @Intentos=t.Intentos,@EmailDestino=t.EmailDestino
        FROM dbo.TokensCorreo t WITH(UPDLOCK,HOLDLOCK)
        WHERE t.IdUsuario=@IdUsuario AND t.Proposito='Verificacion' AND t.UsadoEn IS NULL
        ORDER BY t.IdToken DESC;
        IF @IdToken IS NULL
        BEGIN
            ROLLBACK;
            THROW 50114,@MensajeCodigo,1;
        END;
        IF @ExpiraEn<=@Ahora
        BEGIN
            -- Un cÃƒÂ³digo vencido se quema y obliga a solicitar uno nuevo.
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50114,@MensajeCodigo,1;
        END;
        IF @Intentos>=5
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50115,N'Agotaste los intentos de este cÃƒÂ³digo. Solicita uno nuevo.',1;
        END;
        SELECT @EmailActual=COALESCE(c.Email,e.Email)
        FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.IdUsuario=@IdUsuario;
        IF @EmailActual IS NULL OR @EmailActual<>@EmailDestino
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50116,N'El correo de la cuenta cambiÃƒÂ³. Solicita un nuevo cÃƒÂ³digo.',1;
        END;
        IF @HashGuardado<>@CodigoHash
        BEGIN
            DECLARE @NuevosIntentos TINYINT=CONVERT(TINYINT,@Intentos+1);
            IF @NuevosIntentos>=5
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos,UsadoEn=@Ahora WHERE IdToken=@IdToken;
            ELSE
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos WHERE IdToken=@IdToken;
            -- COMMIT explÃƒÂ­cito antes del THROW: el contador de intentos no debe revertirse.
            COMMIT;
            DECLARE @Restantes INT=CASE WHEN @NuevosIntentos>=5 THEN 0 ELSE 5-CONVERT(INT,@NuevosIntentos) END;
            DECLARE @MensajeIncorrecto NVARCHAR(2048)=N'CÃƒÂ³digo incorrecto. Te quedan '+CONVERT(NVARCHAR(10),@Restantes)+N' intentos.';
            THROW 50113,@MensajeIncorrecto,1;
        END;
        UPDATE dbo.Usuarios SET EmailVerificado=@EmailDestino,EmailVerificadoEn=@Ahora
        WHERE IdUsuario=@IdUsuario;
        UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT CONVERT(BIT,1) AS Verificado,@EmailDestino AS EmailVerificado,@Ahora AS VerificadoEn;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_RestablecerClave
    @Identificador VARCHAR(150),@CodigoHash VARBINARY(32),@NuevoHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF @NuevoHash IS NULL OR LEFT(@NuevoHash,14)<>'PBKDF2-SHA256$'
        THROW 50112,'No se pudo preparar la nueva contraseÃƒÂ±a.',1;
    IF @CodigoHash IS NULL OR DATALENGTH(@CodigoHash)<>32
        THROW 50110,'Los datos del cÃƒÂ³digo de correo no son vÃƒÂ¡lidos.',1;
    SET @Identificador=NULLIF(LTRIM(RTRIM(@Identificador)),'');
    DECLARE @MensajeCodigo NVARCHAR(2048)=N'CÃƒÂ³digo incorrecto o vencido. Solicita uno nuevo.';
    IF @Identificador IS NULL THROW 50113,@MensajeCodigo,1;
    DECLARE @IdUsuario INT=NULL,@Coincidencias INT=0,@Email VARCHAR(150)=NULL;
    SELECT @IdUsuario=MIN(u.IdUsuario),@Coincidencias=COUNT(*)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.NombreUsuario=@Identificador AND u.Activo=1
      AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1));
    IF @Coincidencias<>1 SET @IdUsuario=NULL;
    IF @IdUsuario IS NULL
    BEGIN
        SET @Coincidencias=0;
        SELECT @IdUsuario=MIN(u.IdUsuario),@Coincidencias=COUNT(*)
        FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE (c.Email=@Identificador OR e.Email=@Identificador) AND u.Activo=1
          AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1));
        IF @Coincidencias<>1 SET @IdUsuario=NULL;
    END;
    -- Mismo mensaje genÃƒÂ©rico que un cÃƒÂ³digo incorrecto: no se revela si la cuenta existe.
    IF @IdUsuario IS NULL THROW 50113,@MensajeCodigo,1;
    SELECT @Email=COALESCE(c.Email,e.Email)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.IdUsuario=@IdUsuario;
    IF @Email IS NULL THROW 50113,@MensajeCodigo,1;
    DECLARE @IdToken INT=NULL,@HashGuardado VARBINARY(32)=NULL,@ExpiraEn DATETIME2(0)=NULL,
        @Intentos TINYINT=0,@EmailDestino VARCHAR(150)=NULL,@EmailActual VARCHAR(150)=NULL;
    DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME();
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT TOP (1) @IdToken=t.IdToken,@HashGuardado=t.CodigoHash,@ExpiraEn=t.ExpiraEn,
            @Intentos=t.Intentos,@EmailDestino=t.EmailDestino
        FROM dbo.TokensCorreo t WITH(UPDLOCK,HOLDLOCK)
        WHERE t.IdUsuario=@IdUsuario AND t.Proposito='Recuperacion' AND t.UsadoEn IS NULL
        ORDER BY t.IdToken DESC;
        IF @IdToken IS NULL
        BEGIN
            ROLLBACK;
            THROW 50114,@MensajeCodigo,1;
        END;
        IF @ExpiraEn<=@Ahora
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50114,@MensajeCodigo,1;
        END;
        IF @Intentos>=5
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50115,N'Agotaste los intentos de este cÃƒÂ³digo. Solicita uno nuevo.',1;
        END;
        SELECT @EmailActual=COALESCE(c.Email,e.Email)
        FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.IdUsuario=@IdUsuario;
        IF @EmailActual IS NULL OR @EmailActual<>@EmailDestino
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50116,N'El correo de la cuenta cambiÃƒÂ³. Solicita un nuevo cÃƒÂ³digo.',1;
        END;
        IF @HashGuardado<>@CodigoHash
        BEGIN
            DECLARE @NuevosIntentos TINYINT=CONVERT(TINYINT,@Intentos+1);
            IF @NuevosIntentos>=5
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos,UsadoEn=@Ahora WHERE IdToken=@IdToken;
            ELSE
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50113,@MensajeCodigo,1;
        END;
        UPDATE dbo.Usuarios SET ClaveHash=@NuevoHash,Clave=CONVERT(VARCHAR(255),NEWID()),ClaveVersion=ClaveVersion+1,
            EmailVerificado=@EmailDestino,EmailVerificadoEn=@Ahora
        WHERE IdUsuario=@IdUsuario;
        UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdUsuario=@IdUsuario AND UsadoEn IS NULL;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdUsuario AS IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE [dbo].[usp_ValidarLogin]
    @NombreUsuario VARCHAR(50),
    @Clave VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdUsuario INT;

    SELECT @IdUsuario = u.IdUsuario
    FROM dbo.Usuarios AS u
    LEFT JOIN dbo.Clientes AS c
        ON c.IdCliente = u.IdCliente
    LEFT JOIN dbo.Empleados AS e
        ON e.IdEmpleado = u.IdEmpleado
    WHERE u.NombreUsuario = @NombreUsuario
      AND u.Clave COLLATE Latin1_General_100_BIN2
          = @Clave COLLATE Latin1_General_100_BIN2
      AND DATALENGTH(u.Clave) = DATALENGTH(@Clave)
      AND u.Activo = 1
      AND
      (
          (u.TipoUsuario = 'Cliente' AND c.Activo = 1)
          OR
          (u.TipoUsuario IN ('Empleado', 'Administrador')
           AND e.Activo = 1)
      );

    IF @IdUsuario IS NOT NULL
    BEGIN
        SELECT
            CAST(1 AS BIT) AS LoginValido,
            IdUsuario,
            NombreUsuario,
            TipoUsuario,
            ClaveVersion,
            IdCliente,
            IdEmpleado
        FROM dbo.Usuarios
        WHERE IdUsuario = @IdUsuario;
    END
    ELSE
    BEGIN
        SELECT
            CAST(0 AS BIT) AS LoginValido,
            CAST(NULL AS INT) AS IdUsuario,
            CAST(NULL AS VARCHAR(50)) AS NombreUsuario,
            CAST(NULL AS VARCHAR(20)) AS TipoUsuario,
            CAST(NULL AS INT) AS ClaveVersion,
            CAST(NULL AS INT) AS IdCliente,
            CAST(NULL AS INT) AS IdEmpleado;
    END;
END;
GO
-- Permisos condicionados de los procedimientos de correo.
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ramses_proyecto' AND type IN ('S','U','G'))
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.app_CorreoEstado TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_CrearTokenCorreo TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_SolicitarRecuperacion TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ConfirmarCorreo TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_RestablecerClave TO [ramses_proyecto];
END;
GO
-- Permiso condicionado: Activar-Mejoras.ps1 corre todo en una transacciÃƒÂ³n y un GRANT fallido
-- (por ejemplo, si el login no existe todavÃƒÂ­a) revertirÃƒÂ­a toda la activaciÃƒÂ³n.
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ramses_proyecto' AND type IN ('S','U','G'))
    GRANT EXECUTE ON OBJECT::dbo.app_AutoRegistroCliente TO [ramses_proyecto];
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearPedido @IdUsuario INT,@IdCliente INT=NULL,@Observaciones VARCHAR(300)='',@Lineas NVARCHAR(MAX)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; EXEC dbo.app_Autorizar @IdUsuario;
 IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente') SELECT @IdCliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario;
 IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente AND Activo=1) THROW 50101,'Selecciona un cliente activo.',1;
 IF ISJSON(@Lineas)<>1 THROW 50101,'El detalle del pedido no es v?lido.',1;
 DECLARE @Detalle TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2));
 IF EXISTS(SELECT IdServicio FROM OPENJSON(@Lineas) WITH(IdServicio INT '$.serviceId') GROUP BY IdServicio HAVING COUNT(*)>1) THROW 50101,'Cada servicio debe aparecer una sola vez.',1;
 INSERT @Detalle SELECT IdServicio,Cantidad FROM OPENJSON(@Lineas) WITH(IdServicio INT '$.serviceId',Cantidad DECIMAL(10,2) '$.quantity');
 IF (SELECT COUNT(*) FROM @Detalle) NOT BETWEEN 1 AND 30 OR EXISTS(SELECT 1 FROM @Detalle WHERE Cantidad IS NULL OR Cantidad<=0 OR Cantidad>10000) THROW 50101,'Agrega de 1 a 30 servicios con cantidades positivas.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Tarifas TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2),Base DECIMAL(10,2),Adicional DECIMAL(18,2));
  INSERT @Tarifas SELECT d.IdServicio,d.Cantidad,s.PrecioBase,CASE WHEN d.Cantidad>s.CantidadIncluida THEN(d.Cantidad-s.CantidadIncluida)*COALESCE(s.PrecioAdicional,0) ELSE 0 END FROM @Detalle d JOIN dbo.Servicios s WITH(UPDLOCK,HOLDLOCK) ON s.IdServicio=d.IdServicio AND s.Activo=1;
  IF (SELECT COUNT(*) FROM @Tarifas)<>(SELECT COUNT(*) FROM @Detalle) THROW 50101,'Uno de los servicios no existe o est? inactivo.',1;
  IF EXISTS(SELECT 1 FROM @Detalle d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio WHERE s.TipoCobro<>'Kilogramo' AND d.Cantidad<>FLOOR(d.Cantidad)) THROW 50101,'Las cantidades deben ser enteras.',1;
  INSERT dbo.Pedidos(IdCliente,Estado,Total,Observaciones) VALUES(@IdCliente,'Pendiente',0,@Observaciones);
   DECLARE @IdPedido INT=CONVERT(INT,SCOPE_IDENTITY()),@Email VARCHAR(150),@Json NVARCHAR(MAX);
   INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal) SELECT @IdPedido,IdServicio,Cantidad,Base,Adicional,Base+Adicional FROM @Tarifas;
   UPDATE dbo.Pedidos SET Total=COALESCE((SELECT SUM(Subtotal) FROM dbo.DetallePedido WHERE IdPedido=@IdPedido),0) WHERE IdPedido=@IdPedido;
  SELECT @Email=NULLIF(TRIM(Email),'') FROM dbo.Clientes WHERE IdCliente=@IdCliente;
  IF @Email IS NOT NULL
  BEGIN
   SELECT @Json=(SELECT p.IdPedido,p.Estado,p.FechaPedido,p.Total,p.Observaciones,c.IdCliente,c.Nombre,c.Apellidos,c.Email,JSON_QUERY((SELECT d.IdDetalle,d.IdServicio,s.NombreServicio,d.Cantidad,d.PrecioBase,d.MontoAdicional,d.Subtotal FROM dbo.DetallePedido d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio WHERE d.IdPedido=p.IdPedido ORDER BY d.IdDetalle FOR JSON PATH)) Detalle FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente WHERE p.IdPedido=@IdPedido FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   IF NOT EXISTS(SELECT 1 FROM dbo.CorreoEnvios WITH(UPDLOCK,HOLDLOCK) WHERE ClaveUnica=CONCAT('pedido:',@IdPedido,':confirmacion')) INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,IdPedido,Destino,Asunto,DatosJson) VALUES('PedidoCreado',CONCAT('pedido:',@IdPedido,':confirmacion'),@IdPedido,@Email,CONCAT('Confirmaci?n de pedido #',@IdPedido),@Json);
  END;
  COMMIT; SELECT IdPedido,Total,Estado FROM dbo.Pedidos WHERE IdPedido=@IdPedido;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ActualizarPagoSeguro @IdUsuario INT,@IdPago INT,@IdPedido INT,@Monto DECIMAL(10,2),@MetodoPago VARCHAR(20),@EstadoPago VARCHAR(20),@Referencia VARCHAR(100)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; EXEC dbo.app_ExigirAdministrador @IdUsuario;
 IF @EstadoPago NOT IN('Pendiente','Pagado','Anulado') OR @MetodoPago NOT IN('Efectivo','SINPE Movil') OR @Monto<=0 THROW 50101,'Los datos del pago no son v?lidos.',1;
 BEGIN TRY BEGIN TRANSACTION;
   DECLARE @Anterior VARCHAR(20),@PedidoExistente INT,@TotalPedido DECIMAL(10,2),@Email VARCHAR(150),@Json NVARCHAR(MAX);
   SELECT @Anterior=pg.EstadoPago,@PedidoExistente=pg.IdPedido,@TotalPedido=p.Total
   FROM dbo.Pagos pg WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Pedidos p WITH(UPDLOCK,HOLDLOCK) ON p.IdPedido=pg.IdPedido
   WHERE pg.IdPago=@IdPago;
  IF @Anterior IS NULL THROW 50104,'El pago no existe.',1;
   IF @PedidoExistente<>@IdPedido THROW 50101,'El pago no pertenece al pedido indicado.',1;
   IF @Monto>@TotalPedido THROW 50101,'El monto del pago no puede superar el total del pedido.',1;
    IF NOT ((@Anterior='Pendiente' AND @EstadoPago IN('Pendiente','Pagado','Anulado')) OR (@Anterior='Pagado' AND @EstadoPago='Pagado') OR (@Anterior='Anulado' AND @EstadoPago='Anulado')) THROW 50101,'La transición del estado del pago no es válida.',1;
   IF @Anterior='Anulado' AND @EstadoPago='Anulado'
   BEGIN
    COMMIT; SELECT * FROM dbo.Pagos WHERE IdPago=@IdPago; RETURN;
   END;
  UPDATE dbo.Pagos SET IdPedido=@IdPedido,Monto=@Monto,MetodoPago=@MetodoPago,EstadoPago=@EstadoPago,Referencia=@Referencia WHERE IdPago=@IdPago;
  IF @Anterior<>'Pagado' AND @EstadoPago='Pagado'
  BEGIN
   SELECT @Email=NULLIF(TRIM(c.Email),'') FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente WHERE p.IdPedido=@IdPedido;
   IF @Email IS NOT NULL
   BEGIN
    SELECT @Json=(SELECT pg.IdPago,pg.IdPedido,pg.FechaPago,pg.Monto,pg.MetodoPago,pg.EstadoPago,pg.Referencia,p.Total TotalPedido,c.IdCliente,c.Nombre,c.Apellidos,c.Email FROM dbo.Pagos pg JOIN dbo.Pedidos p ON p.IdPedido=pg.IdPedido JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente WHERE pg.IdPago=@IdPago FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    IF NOT EXISTS(SELECT 1 FROM dbo.CorreoEnvios WITH(UPDLOCK,HOLDLOCK) WHERE ClaveUnica=CONCAT('pago:',@IdPago,':comprobante')) INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,IdPedido,IdPago,Destino,Asunto,DatosJson) VALUES('ComprobantePago',CONCAT('pago:',@IdPago,':comprobante'),@IdPedido,@IdPago,@Email,CONCAT('Comprobante de pago #',@IdPago),@Json);
   END;
  END;
  COMMIT; SELECT * FROM dbo.Pagos WHERE IdPago=@IdPago;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EncolarComprobantePago @IdUsuario INT,@IdPago INT,@IdPedido INT,@Monto DECIMAL(10,2),@MetodoPago VARCHAR(20),@EstadoPago VARCHAR(20),@Referencia VARCHAR(100)=NULL
AS BEGIN SET NOCOUNT ON; EXEC dbo.app_ActualizarPagoSeguro @IdUsuario,@IdPago,@IdPedido,@Monto,@MetodoPago,@EstadoPago,@Referencia; END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ReclamarCorreo @Lote INT=10
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; IF @Lote IS NULL OR @Lote NOT BETWEEN 1 AND 1000 THROW 50101,'El lote debe estar entre 1 y 1000.',1;
 DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME(); BEGIN TRANSACTION;
 ;WITH C AS(SELECT TOP(@Lote) * FROM dbo.CorreoEnvios WITH(UPDLOCK,READPAST,ROWLOCK) WHERE(Estado='Pendiente' AND ProximoIntento<=@Ahora) OR(Estado='Procesando' AND ProcesandoHasta<=@Ahora) ORDER BY ProximoIntento,IdEnvio)
  UPDATE C SET Estado='Procesando',TokenLease=NEWID(),ProcesandoHasta=DATEADD(MINUTE,2,@Ahora)
  OUTPUT inserted.IdEnvio,inserted.Tipo,inserted.ClaveUnica,inserted.IdPedido,inserted.IdPago,inserted.Destino,inserted.Asunto,inserted.DatosJson,inserted.Estado,inserted.Intentos,inserted.ProximoIntento,inserted.TokenLease,inserted.ProcesandoHasta,inserted.CreadoEn,inserted.EnviadoEn,inserted.UltimoError;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ResolverCorreo @IdEnvio BIGINT,@TokenLease UNIQUEIDENTIFIER,@Exito BIT,@Error VARCHAR(1000)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME(); BEGIN TRY BEGIN TRANSACTION;
   IF NOT EXISTS(SELECT 1 FROM dbo.CorreoEnvios WITH(UPDLOCK,HOLDLOCK) WHERE IdEnvio=@IdEnvio AND Estado='Procesando' AND TokenLease=@TokenLease) THROW 50104,'El env?o no existe, no est? en procesamiento o el lease ya expir?.',1;
   IF @Exito=1 UPDATE dbo.CorreoEnvios SET Estado='Enviado',TokenLease=NULL,EnviadoEn=@Ahora,ProcesandoHasta=NULL,UltimoError=NULL WHERE IdEnvio=@IdEnvio AND Estado='Procesando' AND TokenLease=@TokenLease;
   ELSE UPDATE dbo.CorreoEnvios SET Intentos=Intentos+1,Estado=CASE WHEN Intentos+1>=5 THEN 'Error' ELSE 'Pendiente' END,ProximoIntento=DATEADD(MINUTE,CASE Intentos+1 WHEN 1 THEN 1 WHEN 2 THEN 5 WHEN 3 THEN 15 ELSE 60 END,@Ahora),TokenLease=NULL,ProcesandoHasta=NULL,UltimoError=LEFT(COALESCE(@Error,'Error no especificado'),1000) WHERE IdEnvio=@IdEnvio AND Estado='Procesando' AND TokenLease=@TokenLease;
  COMMIT; SELECT * FROM dbo.CorreoEnvios WHERE IdEnvio=@IdEnvio;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_DatosCorreoPedido @IdUsuario INT,@IdPedido INT
AS
BEGIN
 SET NOCOUNT ON;
 EXEC dbo.app_Autorizar @IdUsuario;
 IF NOT EXISTS(
     SELECT 1 FROM dbo.Pedidos p JOIN dbo.Usuarios u ON u.IdUsuario=@IdUsuario
     WHERE p.IdPedido=@IdPedido
       AND (u.TipoUsuario IN ('Empleado','Administrador') OR p.IdCliente=u.IdCliente)
 ) THROW 50104,'Pedido no disponible para esta cuenta.',1;
 SELECT IdEnvio,Tipo,ClaveUnica,IdPedido,Destino,Asunto,DatosJson,Estado,Intentos,ProximoIntento,ProcesandoHasta,CreadoEn,EnviadoEn,UltimoError
 FROM dbo.CorreoEnvios WHERE IdPedido=@IdPedido AND Tipo='PedidoCreado';
END;
GO
IF EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'ramses_proyecto' AND type IN('S','U','G'))
BEGIN
 GRANT EXECUTE ON OBJECT::dbo.app_ReclamarCorreo TO [ramses_proyecto]; GRANT EXECUTE ON OBJECT::dbo.app_ResolverCorreo TO [ramses_proyecto];
 GRANT EXECUTE ON OBJECT::dbo.app_DatosCorreoPedido TO [ramses_proyecto]; GRANT EXECUTE ON OBJECT::dbo.app_ActualizarPagoSeguro TO [ramses_proyecto]; GRANT EXECUTE ON OBJECT::dbo.app_EncolarComprobantePago TO [ramses_proyecto];
END;
GO
