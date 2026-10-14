USE master;
SET NOCOUNT ON;
IF @@SERVERNAME <> N'MADRENZO'
    THROW 50000, 'Ejecutar solamente en MADRENZO.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name=N'LavaFacil' AND state_desc=N'ONLINE' AND recovery_model_desc=N'FULL')
    THROW 50000, 'La base principal debe estar ONLINE y en FULL.', 1;
IF EXISTS (SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID(N'LavaFacil') AND mirroring_partner_name IS NOT NULL AND mirroring_partner_name <> N'TCP://100.117.134.120:5022')
    THROW 50000, 'Ya hay otro compañero configurado. No se modificó.', 1;
IF EXISTS (SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID(N'LavaFacil') AND mirroring_role_desc=N'MIRROR')
    THROW 50000, 'MADRENZO no figura como principal. No se modificó.', 1;
IF EXISTS (SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID(N'LavaFacil') AND mirroring_partner_name IS NULL)
    ALTER DATABASE [LavaFacil] SET PARTNER = 'TCP://100.117.134.120:5022';
SELECT DB_NAME(database_id) AS BaseActual,mirroring_role_desc AS Rol,
    mirroring_state_desc AS Estado,mirroring_partner_name AS Companero,
    mirroring_safety_level_desc AS Seguridad,mirroring_witness_state_desc AS Testigo
FROM sys.database_mirroring WHERE database_id=DB_ID(N'LavaFacil');
