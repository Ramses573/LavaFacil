SET NOCOUNT ON;
DECLARE @k varchar(200)='qa-lease-final-'+CONVERT(varchar(36),NEWID()), @id bigint, @tok uniqueidentifier, @bad uniqueidentifier=NEWID(), @ok bit, @err varchar(1000);
INSERT dbo.CorreoEnvios(Tipo,ClaveUnica,Destino,Asunto,DatosJson,Estado,Intentos,ProximoIntento,CreadoEn)
VALUES('QALease',@k,'qa@example.test','QA','{}','Pendiente',0,SYSUTCDATETIME(),SYSUTCDATETIME());
SET @id=SCOPE_IDENTITY();
DECLARE @c table(IdEnvio bigint,Tipo varchar(100),ClaveUnica varchar(200),IdPedido int,IdPago int,Destino varchar(500),Asunto varchar(500),DatosJson nvarchar(max),Estado varchar(50),Intentos int,ProximoIntento datetime2,TokenLease uniqueidentifier,ProcesandoHasta datetime2,CreadoEn datetime2,EnviadoEn datetime2,UltimoError varchar(1000));
INSERT @c EXEC dbo.app_ReclamarCorreo @Lote=1;
SELECT @tok=TokenLease FROM @c WHERE IdEnvio=@id;
SELECT 'claim' CheckName,CASE WHEN @tok IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@id AND Estado='Procesando' AND TokenLease=@tok) THEN 'PASS' ELSE 'FAIL' END Estado;
SET @ok=NULL;SET @err=NULL;EXEC dbo.app_ResolverCorreo @IdEnvio=@id,@TokenLease=@bad,@Exito=@ok OUTPUT,@Error=@err OUTPUT;
SELECT 'wrong-token' CheckName,CASE WHEN EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@id AND Estado='Procesando' AND TokenLease=@tok) THEN 'PASS' ELSE 'FAIL' END Estado,@ok Exito,@err Error;
SET @ok=NULL;SET @err=NULL;EXEC dbo.app_ResolverCorreo @IdEnvio=@id,@TokenLease=@tok,@Exito=1,@Error=NULL;
SELECT 'correct-token' CheckName,CASE WHEN EXISTS(SELECT 1 FROM dbo.CorreoEnvios WHERE IdEnvio=@id AND Estado='Enviado' AND TokenLease IS NULL) THEN 'PASS' ELSE 'FAIL' END Estado,@ok Exito,@err Error;
DELETE dbo.CorreoEnvios WHERE IdEnvio=@id;
