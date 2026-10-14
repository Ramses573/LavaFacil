USE master;
SET NOCOUNT ON;
IF @@SERVERNAME <> N'LAPTOP-D0TECCJR\LAVAFACIL2022'
    THROW 50000, 'No se confirmó el servidor de Rachel. No se ejecutó otra conmutación.', 1;
IF NOT EXISTS (
 SELECT 1 FROM sys.database_mirroring WHERE database_id=DB_ID(N'LavaFacil')
 AND mirroring_role_desc=N'PRINCIPAL' AND mirroring_state_desc=N'SYNCHRONIZED'
 AND mirroring_safety_level_desc=N'FULL' AND mirroring_partner_name=N'TCP://100.98.252.109:5022'
)
    THROW 50000, 'Rachel debe estar como principal sincronizado en FULL con MADRENZO.', 1;
ALTER DATABASE [LavaFacil] SET PARTNER FAILOVER;
SELECT N'Conmutación de regreso ejecutada. Verificar mediante una conexión nueva.' AS Resultado;
