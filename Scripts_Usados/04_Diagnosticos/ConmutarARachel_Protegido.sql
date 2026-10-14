USE master;
SET NOCOUNT ON;
IF @@SERVERNAME <> N'MADRENZO'
    THROW 50000, 'La conmutación debe iniciar desde MADRENZO como principal.', 1;
IF NOT EXISTS (
    SELECT 1 FROM sys.database_mirroring
    WHERE database_id=DB_ID(N'LavaFacil')
      AND mirroring_role_desc=N'PRINCIPAL'
      AND mirroring_state_desc=N'SYNCHRONIZED'
      AND mirroring_safety_level_desc=N'FULL'
      AND mirroring_partner_name=N'TCP://100.117.134.120:5022'
)
    THROW 50000, 'No se confirmó principal sincronizado con Rachel. No se ejecutó failover.', 1;
ALTER DATABASE [LavaFacil] SET PARTNER FAILOVER;
SELECT N'Comando de conmutación ejecutado; verificar roles mediante una conexión nueva.' AS Resultado;
