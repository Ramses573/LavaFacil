-- Normaliza el precio adicional de los servicios de demostración.
-- Regla: un servicio sin PrecioAdicional cobra el excedente de cantidad.
-- Los valores reproducen la configuración validada en el servidor MADRENZO.
-- Idempotente: solo actualiza filas con PrecioAdicional 0 o NULL.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.Servicios
       SET PrecioAdicional = CASE IdServicio
           WHEN 4 THEN 750.00
           WHEN 5 THEN 1250.00
           WHEN 6 THEN 1000.00
           WHEN 7 THEN 500.00
       END
     WHERE IdServicio IN (4, 5, 6, 7)
       AND (PrecioAdicional IS NULL OR PrecioAdicional = 0);

    PRINT CONCAT('Servicios con precio adicional normalizado: ', @@ROWCOUNT);

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;