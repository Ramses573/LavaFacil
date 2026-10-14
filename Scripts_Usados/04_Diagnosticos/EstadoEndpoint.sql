USE master;
GO
SELECT @@SERVERNAME AS Servidor, ORIGINAL_LOGIN() AS LoginActual,
 HAS_PERMS_BY_NAME(NULL,'SERVER','VIEW ANY DEFINITION') AS PuedeVerDefinicionesServidor;
SELECT e.name,e.state_desc,m.role_desc,m.connection_auth_desc,m.encryption_algorithm_desc,t.port
FROM sys.endpoints e
JOIN sys.database_mirroring_endpoints m ON m.endpoint_id=e.endpoint_id
JOIN sys.tcp_endpoints t ON t.endpoint_id=e.endpoint_id;
GO
