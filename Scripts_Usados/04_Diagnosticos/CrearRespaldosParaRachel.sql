USE master;
SET NOCOUNT ON;
IF @@SERVERNAME <> N'MADRENZO'
    THROW 50000, 'Este script es solamente para MADRENZO.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name=N'LavaFacil' AND state_desc=N'ONLINE' AND recovery_model_desc=N'FULL')
    THROW 50000, 'LavaFacil debe estar ONLINE y en FULL.', 1;
DECLARE @Sufijo VARCHAR(36)=CONVERT(VARCHAR(36),NEWID());
DECLARE @Completo NVARCHAR(260)=N'C:\Mirroring\LavaFacil_Rachel_'+@Sufijo+N'.bak';
DECLARE @Log NVARCHAR(260)=N'C:\Mirroring\LavaFacil_Rachel_'+@Sufijo+N'.trn';
BACKUP DATABASE LavaFacil TO DISK=@Completo
WITH COPY_ONLY, CHECKSUM, COMPRESSION, STATS=10;
BACKUP LOG LavaFacil TO DISK=@Log
WITH CHECKSUM, COMPRESSION, STATS=10;
SELECT @Completo AS RespaldoCompleto, @Log AS RespaldoLog;
