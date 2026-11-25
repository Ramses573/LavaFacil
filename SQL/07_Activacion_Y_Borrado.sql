-- ============================================================================
-- LavaFacil · 07_Activacion_Y_Borrado.sql
-- Migración idempotente:
--   1. Activación obligatoria por correo para clientes autoregistrados.
--   2. Borrado físico de pedidos (sin pagos, Pendiente/Cancelado) y de líneas
--      de detalle (pedidos Pendientes), con recálculo del total.
-- Ejecutar en LavaFacil con un login que pueda ALTER/EXECUTE (ramses_proyecto).
-- ============================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ---------------------------------------------------------------------------
-- 1. Columna de activación pendiente
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.Usuarios','ActivacionPendiente') IS NULL
    ALTER TABLE dbo.Usuarios
        ADD ActivacionPendiente BIT NOT NULL
            CONSTRAINT DF_Usuarios_ActivacionPendiente DEFAULT(0);
GO

-- ---------------------------------------------------------------------------
-- 2. Auto-registro: toda cuenta nueva creada desde la página pública queda
--    pendiente de activar hasta confirmar el código enviado al correo.
-- ---------------------------------------------------------------------------
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
        THROW 50101,'No se pudo preparar la contraseña para guardarla.',1;
    DECLARE @IdCliente INT=NULL,@IdUsuario INT=NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Guard de bootstrap: el auto-registro no puede crear el primer usuario si aún no hay administrador.
        IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WITH(TABLOCKX,HOLDLOCK))
            THROW 50102,'La creación inicial de la cuenta de administrador está pendiente. Configura primero el administrador.',1;
        -- UPDLOCK+HOLDLOCK serializa los pre-chequeos; un único mensaje genérico evita enumerar qué dato ya existe.
        IF EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE Cedula=TRIM(@Cedula))
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesión o contacta al administrador.',1;
        IF EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE Email=TRIM(@Email))
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesión o contacta al administrador.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE NombreUsuario=TRIM(@NombreUsuario))
            THROW 50103,'No pudimos crear la cuenta con esos datos. Si ya tienes una cuenta, inicia sesión o contacta al administrador.',1;
        -- Siempre se crea un cliente nuevo; nunca se enlaza a un IdCliente existente (evita robo de cuenta).
        INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email,Direccion,Activo)
        VALUES(TRIM(@Cedula),TRIM(@Nombre),TRIM(@Apellidos),TRIM(@Telefono),TRIM(@Email),NULLIF(TRIM(@Direccion),''),1);
        SET @IdCliente=CONVERT(INT,SCOPE_IDENTITY());
        -- Clave recibe un valor aleatorio y el hash va en ClaveHash.
        -- ActivacionPendiente=1: la cuenta existe pero no puede usar el sitio hasta verificar el correo.
        INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdCliente,Activo,ActivacionPendiente)
        VALUES(TRIM(@NombreUsuario),CONVERT(VARCHAR(255),NEWID()),@Hash,'Cliente',@IdCliente,1,1);
        SET @IdUsuario=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdUsuario AS IdUsuario,@IdCliente AS IdCliente;
END;
GO

-- ---------------------------------------------------------------------------
-- 3. Confirmar correo: además de marcar el correo, levanta la activación.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_ConfirmarCorreo
    @IdUsuario INT,@CodigoHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @CodigoHash IS NULL OR DATALENGTH(@CodigoHash)<>32
        THROW 50110,'Los datos del código de correo no son válidos.',1;
    DECLARE @IdToken INT=NULL,@HashGuardado VARBINARY(32)=NULL,@ExpiraEn DATETIME2(0)=NULL,
        @Intentos TINYINT=0,@EmailDestino VARCHAR(150)=NULL,@EmailActual VARCHAR(150)=NULL;
    DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME();
    DECLARE @MensajeCodigo NVARCHAR(2048)=N'El código no es válido o ya venció. Solicita uno nuevo.';
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
            -- Un código vencido se quema y obliga a solicitar uno nuevo.
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50114,@MensajeCodigo,1;
        END;
        IF @Intentos>=5
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50115,N'Agotaste los intentos de este código. Solicita uno nuevo.',1;
        END;
        SELECT @EmailActual=COALESCE(c.Email,e.Email)
        FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.IdUsuario=@IdUsuario;
        IF @EmailActual IS NULL OR @EmailActual<>@EmailDestino
        BEGIN
            UPDATE dbo.TokensCorreo SET UsadoEn=@Ahora WHERE IdToken=@IdToken;
            COMMIT;
            THROW 50116,N'El correo de la cuenta cambió. Solicita un nuevo código.',1;
        END;
        IF @HashGuardado<>@CodigoHash
        BEGIN
            DECLARE @NuevosIntentos TINYINT=CONVERT(TINYINT,@Intentos+1);
            IF @NuevosIntentos>=5
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos,UsadoEn=@Ahora WHERE IdToken=@IdToken;
            ELSE
                UPDATE dbo.TokensCorreo SET Intentos=@NuevosIntentos WHERE IdToken=@IdToken;
            -- COMMIT explícito antes del THROW: el contador de intentos no debe revertirse.
            COMMIT;
            DECLARE @Restantes INT=CASE WHEN @NuevosIntentos>=5 THEN 0 ELSE 5-CONVERT(INT,@NuevosIntentos) END;
            DECLARE @MensajeIncorrecto NVARCHAR(2048)=N'Código incorrecto. Te quedan '+CONVERT(NVARCHAR(10),@Restantes)+N' intentos.';
            THROW 50113,@MensajeIncorrecto,1;
        END;
        UPDATE dbo.Usuarios SET EmailVerificado=@EmailDestino,EmailVerificadoEn=@Ahora,ActivacionPendiente=0
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

-- ---------------------------------------------------------------------------
-- 4. Estado de correo: expone ActivacionPendiente para que la app bloquee
--    el acceso hasta que el cliente autoregistrado verifique su correo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_CorreoEstado @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    DECLARE @Email VARCHAR(150)=NULL,@Verificado BIT=0,@VerificadoEn DATETIME2(0)=NULL,@ActivacionPendiente BIT=0;
    SELECT @Email=COALESCE(c.Email,e.Email),
        @Verificado=CONVERT(BIT,CASE WHEN u.EmailVerificado IS NOT NULL AND u.EmailVerificado=COALESCE(c.Email,e.Email) THEN 1 ELSE 0 END),
        @VerificadoEn=u.EmailVerificadoEn,
        @ActivacionPendiente=ISNULL(u.ActivacionPendiente,0)
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.IdUsuario=@IdUsuario;
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
        @SegundosEspera AS SegundosEspera,@IntentosRestantes AS IntentosRestantes,
        @ActivacionPendiente AS ActivacionPendiente;
END;
GO

-- ---------------------------------------------------------------------------
-- 5. Login: expone ActivacionPendiente para el frontend.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_Credencial @NombreUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario,u.NombreUsuario,u.TipoUsuario,u.ClaveVersion,u.ClaveHash,u.ActivacionPendiente
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.NombreUsuario=@NombreUsuario AND u.Activo=1
      AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Administrador','Empleado') AND e.Activo=1));
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
    LEFT JOIN dbo.Clientes AS c ON c.IdCliente = u.IdCliente
    LEFT JOIN dbo.Empleados AS e ON e.IdEmpleado = u.IdEmpleado
    WHERE u.NombreUsuario = @NombreUsuario
      AND u.Clave COLLATE Latin1_General_100_BIN2 = @Clave COLLATE Latin1_General_100_BIN2
      AND DATALENGTH(u.Clave) = DATALENGTH(@Clave)
      AND u.Activo = 1
      AND ((u.TipoUsuario = 'Cliente' AND c.Activo = 1)
        OR (u.TipoUsuario IN ('Empleado', 'Administrador') AND e.Activo = 1));
    IF @IdUsuario IS NOT NULL
    BEGIN
        SELECT CAST(1 AS BIT) AS LoginValido, IdUsuario, NombreUsuario, TipoUsuario,
            ClaveVersion, IdCliente, IdEmpleado, ActivacionPendiente
        FROM dbo.Usuarios WHERE IdUsuario = @IdUsuario;
    END
    ELSE
    BEGIN
        SELECT CAST(0 AS BIT) AS LoginValido, CAST(NULL AS INT) AS IdUsuario,
            CAST(NULL AS VARCHAR(50)) AS NombreUsuario, CAST(NULL AS VARCHAR(20)) AS TipoUsuario,
            CAST(NULL AS INT) AS ClaveVersion, CAST(NULL AS INT) AS IdCliente,
            CAST(NULL AS INT) AS IdEmpleado, CAST(0 AS BIT) AS ActivacionPendiente;
    END;
END;
GO

-- ---------------------------------------------------------------------------
-- 6. Activar/desactivar usuario: al activar también se quita la exigencia de
--    verificación (permite que un administrador habilite la cuenta si el
--    correo falla o el cliente no puede recibir el código).
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 7. Consulta de usuarios: el mantenimiento muestra la activación pendiente.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 8. Borrado físico de pedidos (solo personal; sin pagos ni recolecciones y
--    únicamente en estado Pendiente o Cancelado).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_EliminarPedido @IdUsuario INT,@IdPedido INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @IdPedido IS NULL THROW 50101,'El pedido no es válido.',1;
    DECLARE @Estado VARCHAR(20)=NULL,@Pagos INT=0,@Recolecciones INT=0;
    SELECT @Estado=Estado FROM dbo.Pedidos WITH(UPDLOCK,HOLDLOCK) WHERE IdPedido=@IdPedido;
    IF @Estado IS NULL THROW 50104,'El pedido no existe.',1;
    SELECT @Pagos=COUNT(*) FROM dbo.Pagos WHERE IdPedido=@IdPedido;
    IF @Pagos>0 THROW 50101,'No se puede borrar un pedido con pagos registrados.',1;
    SELECT @Recolecciones=COUNT(*) FROM dbo.Recolecciones WHERE IdPedido=@IdPedido;
    IF @Recolecciones>0 THROW 50101,'No se puede borrar un pedido con recolecciones asociadas.',1;
    IF @Estado NOT IN ('Pendiente','Cancelado') THROW 50101,'Solo se pueden borrar pedidos pendientes o cancelados.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM dbo.DetallePedido WHERE IdPedido=@IdPedido;
        -- Se conserva el historial de correos: se desvincula del pedido borrado.
        UPDATE dbo.CorreoEnvios SET IdPedido=NULL WHERE IdPedido=@IdPedido;
        DELETE FROM dbo.Pedidos WHERE IdPedido=@IdPedido;
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdPedido AS IdPedido;
END;
GO

-- ---------------------------------------------------------------------------
-- 9. Borrado de una línea del detalle (solo personal; pedido Pendiente, sin
--    pagos y conservando al menos un servicio). Recalcula el total.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_EliminarDetallePedido @IdUsuario INT,@IdDetalle INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @IdDetalle IS NULL THROW 50101,'El detalle no es válido.',1;
    DECLARE @IdPedido INT=NULL,@Estado VARCHAR(20)=NULL,@Lineas INT=0,@Pagos INT=0;
    SELECT @IdPedido=IdPedido FROM dbo.DetallePedido WITH(UPDLOCK,HOLDLOCK) WHERE IdDetalle=@IdDetalle;
    IF @IdPedido IS NULL THROW 50104,'El detalle no existe.',1;
    SELECT @Estado=Estado FROM dbo.Pedidos WITH(UPDLOCK,HOLDLOCK) WHERE IdPedido=@IdPedido;
    IF @Estado IS NULL THROW 50104,'El pedido no existe.',1;
    SELECT @Pagos=COUNT(*) FROM dbo.Pagos WHERE IdPedido=@IdPedido;
    IF @Pagos>0 THROW 50101,'No se puede modificar un pedido con pagos registrados.',1;
    IF @Estado<>'Pendiente' THROW 50101,'Solo se pueden quitar servicios de pedidos pendientes.',1;
    SELECT @Lineas=COUNT(*) FROM dbo.DetallePedido WHERE IdPedido=@IdPedido;
    IF @Lineas<=1 THROW 50101,'El pedido debe conservar al menos un servicio.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM dbo.DetallePedido WHERE IdDetalle=@IdDetalle;
        UPDATE dbo.Pedidos
            SET Total=ISNULL((SELECT SUM(Subtotal) FROM dbo.DetallePedido WHERE IdPedido=@IdPedido),0)
        WHERE IdPedido=@IdPedido;
        COMMIT;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @IdPedido AS IdPedido,(@Lineas-1) AS Lineas;
END;
GO

-- ---------------------------------------------------------------------------
-- 10. Detalle de pedido: expone IdDetalle para poder quitar líneas.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_DetallePedido @IdUsuario INT,@IdPedido INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Pedidos p CROSS JOIN dbo.Usuarios u
        WHERE p.IdPedido=@IdPedido AND u.IdUsuario=@IdUsuario AND (u.TipoUsuario<>'Cliente' OR p.IdCliente=u.IdCliente))
        THROW 50104,'El pedido no existe o no está disponible para tu cuenta.',1;
    SELECT p.IdPedido,p.Estado,p.Total,p.FechaPedido,p.Observaciones,CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,
        d.IdDetalle,d.IdServicio,s.NombreServicio,s.TipoCobro,d.Cantidad,d.PrecioBase,d.MontoAdicional,d.Subtotal
    FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    JOIN dbo.DetallePedido d ON d.IdPedido=p.IdPedido JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio
    WHERE p.IdPedido=@IdPedido ORDER BY d.IdDetalle;
END;
GO

-- ---------------------------------------------------------------------------
-- 11. Guarda de servidor: un cliente autoregistrado no puede crear pedidos
--     hasta activar su cuenta (evita depender solo del bloqueo visual).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.app_ExigirCuentaActivada @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Usuarios
               WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente'
                 AND ISNULL(ActivacionPendiente,0)=1)
        THROW 50101,'Debes verificar tu correo para activar tu cuenta antes de crear pedidos.',1;
END;
GO

-- ---------------------------------------------------------------------------
-- 12. Permisos condicionados
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ramses_proyecto' AND type IN ('S','U','G'))
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarPedido TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_EliminarDetallePedido TO [ramses_proyecto];
    GRANT EXECUTE ON OBJECT::dbo.app_ExigirCuentaActivada TO [ramses_proyecto];
END;
GO

PRINT '07_Activacion_Y_Borrado.sql aplicado correctamente.';
GO