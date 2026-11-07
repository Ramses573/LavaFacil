SET NOCOUNT ON;
DECLARE @k varchar(200)='qa-lease-reclaim-'+CONVERT(varchar(36),NEWID()), @id bigint, @a uniqueidentifier, @b uniqueidentifier;
INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,Destino,Asunto,DatosJson,Estado,Intentos,ProximoIntento,CreadoEn) VALUES('QALease',@k,'qa@example.test','QA','{}','Pendiente',0,SYSUTCDATETIME(),SYSUTCDATETIME());SET @id=SCOPE_IDENTITY();
DECLARE @c table(IdEnvio bigint,Tipo varchar(100),ClaveUnica varchar(200),IdPedido int,IdPago int,Destino varchar(500),Asunto varchar(500),DatosJson nvarchar(max),Estado varchar(50),Intentos int,ProximoIntento datetime2,TokenLease uniqueidentifier,ProcesandoHasta datetime2,CreadoEn datetime2,EnviadoEn datetime2,UltimoError varchar(1000));
INSERT @c EXEC dbo.app_ReclamarCorreo 1;SELECT @a=TokenLease FROM @c WHERE IdEnvio=@id;UPDATE dbo.CorreoEnvios SET ProcesandoHasta=DATEADD(MINUTE,-1,SYSUTCDATETIME()) WHERE IdEnvio=@id;DELETE FROM @c;INSERT @c EXEC dbo.app_ReclamarCorreo 1;SELECT @b=TokenLease FROM @c WHERE IdEnvio=@id;
SELECT 'reclaim-token-B' CheckName,CASE WHEN @a IS NOT NULL AND @b IS NOT NULL AND @a<>@b THEN 'PASS' ELSE 'FAIL' END Estado;
EXEC dbo.app_ResolverCorreo @IdEnvio=@id,@TokenLease=@a,@Exito=1;SELECT 'old-token-no-change' CheckName,CASE WHEN EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@id AND Estado='Procesando' AND TokenLease=@b) THEN 'PASS' ELSE 'FAIL' END Estado;
EXEC dbo.app_ResolverCorreo @IdEnvio=@id,@TokenLease=@b,@Exito=1;SELECT 'token-B-resolves' CheckName,CASE WHEN EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@id AND Estado='Enviado' AND TokenLease IS NULL) THEN 'PASS' ELSE 'FAIL' END Estado;
DELETE dbo.CorreoEnvios WHERE IdEnvio=@id;
