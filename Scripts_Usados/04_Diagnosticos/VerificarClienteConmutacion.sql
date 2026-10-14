USE LavaFacil;
SELECT @@SERVERNAME AS ServidorConectado;
SELECT IdCliente,Cedula,Nombre,Apellidos,Email,Activo FROM dbo.Clientes
WHERE Cedula='QA-FAILOVER-20261011' AND Email='failover-20261011@example.test';
SELECT mirroring_role_desc AS Rol,mirroring_state_desc AS Estado FROM sys.database_mirroring WHERE database_id=DB_ID();
