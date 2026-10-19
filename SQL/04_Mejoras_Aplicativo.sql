-- Actualización incremental: ejecutar en LavaFacil, en el servidor PRINCIPAL.
-- No restaura bases, no cambia roles de Mirroring y conserva los datos existentes.
USE [LavaFacil];
GO
IF COL_LENGTH('dbo.Usuarios','ClaveHash') IS NULL
    ALTER TABLE dbo.Usuarios ADD ClaveHash VARCHAR(255) NULL;
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
CREATE OR ALTER PROCEDURE dbo.app_ExigirAdministrador @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Administrador')
        THROW 50100,'Esta operación requiere una cuenta administradora.',1;
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
    IF ISJSON(@Lineas)<>1 THROW 50101,'El detalle del pedido no es válido.',1;
    DECLARE @Detalle TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2));
    IF EXISTS(SELECT IdServicio FROM OPENJSON(@Lineas) WITH(IdServicio INT '$.serviceId') GROUP BY IdServicio HAVING COUNT(*)>1)
        THROW 50101,'Cada servicio debe aparecer una sola vez; ajusta su cantidad.',1;
    INSERT @Detalle SELECT IdServicio,Cantidad FROM OPENJSON(@Lineas)
        WITH(IdServicio INT '$.serviceId',Cantidad DECIMAL(10,2) '$.quantity');
    IF (SELECT COUNT(*) FROM @Detalle) NOT BETWEEN 1 AND 30 OR EXISTS(SELECT 1 FROM @Detalle WHERE Cantidad IS NULL OR Cantidad<=0 OR Cantidad>10000)
        THROW 50101,'Agrega de 1 a 30 servicios con cantidades positivas (máximo 10000).',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Bloquea las tarifas seleccionadas hasta terminar el registro completo.
        DECLARE @Tarifas TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2),Base DECIMAL(10,2),Adicional DECIMAL(18,2));
        INSERT @Tarifas
        SELECT d.IdServicio,d.Cantidad,s.PrecioBase,
            CASE WHEN d.Cantidad>s.CantidadIncluida THEN (d.Cantidad-s.CantidadIncluida)*COALESCE(s.PrecioAdicional,0) ELSE 0 END
        FROM @Detalle d JOIN dbo.Servicios s WITH(UPDLOCK,HOLDLOCK) ON s.IdServicio=d.IdServicio AND s.Activo=1;
        IF (SELECT COUNT(*) FROM @Tarifas)<>(SELECT COUNT(*) FROM @Detalle)
            THROW 50101,'Uno de los servicios no existe o está inactivo. Actualiza el catálogo.',1;
        IF EXISTS(SELECT 1 FROM @Detalle d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio WHERE s.TipoCobro<>'Kilogramo' AND d.Cantidad<>FLOOR(d.Cantidad))
            THROW 50101,'Las unidades y los uniformes requieren cantidades enteras.',1;
        IF (SELECT SUM(Base+Adicional) FROM @Tarifas)>99999999.99
            THROW 50101,'El total supera el máximo permitido.',1;
        INSERT dbo.Pedidos(IdCliente,Estado,Total,Observaciones) VALUES(@IdCliente,'Pendiente',0,@Observaciones);
        DECLARE @IdPedido INT=CONVERT(INT,SCOPE_IDENTITY());
        INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal)
        SELECT @IdPedido,IdServicio,Cantidad,Base,Adicional,Base+Adicional FROM @Tarifas;
        -- El trigger existente mantiene Pedidos.Total para todas las líneas.
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
        THROW 50104,'El pedido no existe o no está disponible para tu cuenta.',1;
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
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @Estado NOT IN ('Pendiente','Recibido','En proceso','Listo','Entregado','Cancelado')
        THROW 50101,'Estado de pedido inválido.',1;
    UPDATE dbo.Pedidos SET Estado=@Estado WHERE IdPedido=@IdPedido;
    IF @@ROWCOUNT=0 THROW 50104,'El pedido no existe.',1;
    SELECT @IdPedido AS IdPedido,@Estado AS Estado;
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
        THROW 50101,'Selecciona un avatar y tema válidos.',1;
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
    SELECT u.IdUsuario,u.NombreUsuario,u.TipoUsuario,u.ClaveHash
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
    UPDATE dbo.Usuarios SET ClaveHash=@Hash,Clave=CONVERT(VARCHAR(255),NEWID()) WHERE IdUsuario=@IdUsuario;
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
            THROW 50101,'El cliente no existe o está inactivo.',1;
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
        THROW 50101,'El cliente tiene pedidos relacionados. Desactívalo para conservar su historial.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdCliente=@IdCliente)
        THROW 50101,'El cliente tiene una cuenta de acceso. Desactívalo para conservar su historial.',1;
    DELETE dbo.Clientes WHERE IdCliente=@IdCliente;
    SELECT @IdCliente AS IdCliente;
END;
GO
