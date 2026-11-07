
CREATE   PROCEDURE dbo.app_ReclamarCorreo @Lote INT=10
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; IF @Lote IS NULL OR @Lote NOT BETWEEN 1 AND 1000 THROW 50101,'El lote debe estar entre 1 y 1000.',1;
 DECLARE @Ahora DATETIME2(0)=SYSUTCDATETIME(); BEGIN TRANSACTION;
 ;WITH C AS(SELECT TOP(@Lote) * FROM dbo.CorreoEnvios WITH(UPDLOCK,READPAST,ROWLOCK) WHERE(Estado='Pendiente' AND ProximoIntento<=@Ahora) OR(Estado='Procesando' AND ProcesandoHasta<=@Ahora) ORDER BY ProximoIntento,IdEnvio)
  UPDATE C SET Estado='Procesando',TokenLease=NEWID(),ProcesandoHasta=DATEADD(MINUTE,2,@Ahora)
  OUTPUT inserted.IdEnvio,inserted.Tipo,inserted.ClaveUnica,inserted.IdPedido,inserted.IdPago,inserted.Destino,inserted.Asunto,inserted.DatosJson,inserted.Estado,inserted.Intentos,inserted.ProximoIntento,inserted.TokenLease,inserted.ProcesandoHasta,inserted.CreadoEn,inserted.EnviadoEn,inserted.UltimoError;
 COMMIT;
END;


(1 rows affected)
