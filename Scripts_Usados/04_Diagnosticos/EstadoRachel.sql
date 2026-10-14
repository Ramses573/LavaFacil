USE LavaFacil;
GO
SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseDatos,SERVERPROPERTY('Edition') AS Edicion;
SELECT recovery_model_desc,state_desc,mirroring_state_desc
FROM sys.databases d LEFT JOIN sys.database_mirroring m ON d.database_id=m.database_id
WHERE d.database_id=DB_ID();
SELECT p.name AS UsuarioBase,p.type_desc,r.name AS Rol
FROM sys.database_principals p
LEFT JOIN sys.database_role_members rm ON rm.member_principal_id=p.principal_id
LEFT JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
WHERE p.name=N'rachel_proyecto';
SELECT name,type_desc,is_disabled FROM sys.server_principals WHERE name=N'rachel_proyecto';
SELECT HAS_PERMS_BY_NAME(NULL,'SERVER','VIEW ANY DEFINITION') AS PuedeVerTodosLosLogins;
SELECT name,type_desc FROM sys.objects WHERE name IN ('usp_ValidarLogin','trg_DetallePedido_ActualizarTotal','trg_Pagos_ValidarMonto');
SELECT (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0) AS Tablas,
  (SELECT COUNT(*) FROM dbo.Usuarios) AS CuentasApp,
  (SELECT COUNT(*) FROM dbo.Clientes) AS Clientes,
  (SELECT COUNT(*) FROM dbo.Servicios) AS Servicios;
GO
