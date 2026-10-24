USE [LavaFacil];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_invitado') CREATE ROLE [gql_invitado];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_cliente') CREATE ROLE [gql_cliente];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_empleado') CREATE ROLE [gql_empleado];
GO

-- Los LOGIN se crean en master con contraseñas privadas. Este bloque solamente crea
-- los USER y los incorpora a su rol cuando el login ya existe en la instancia.
IF SUSER_ID(N'lava_gql_invitado') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_invitado') IS NULL CREATE USER [lava_gql_invitado] FOR LOGIN [lava_gql_invitado];
    IF IS_ROLEMEMBER(N'gql_invitado', N'lava_gql_invitado') <> 1 ALTER ROLE [gql_invitado] ADD MEMBER [lava_gql_invitado];
END;
IF SUSER_ID(N'lava_gql_cliente') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_cliente') IS NULL CREATE USER [lava_gql_cliente] FOR LOGIN [lava_gql_cliente];
    IF IS_ROLEMEMBER(N'gql_cliente', N'lava_gql_cliente') <> 1 ALTER ROLE [gql_cliente] ADD MEMBER [lava_gql_cliente];
END;
IF SUSER_ID(N'lava_gql_empleado') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_empleado') IS NULL CREATE USER [lava_gql_empleado] FOR LOGIN [lava_gql_empleado];
    IF IS_ROLEMEMBER(N'gql_empleado', N'lava_gql_empleado') <> 1 ALTER ROLE [gql_empleado] ADD MEMBER [lava_gql_empleado];
END;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_ValidarLogin TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarServicios TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarPromociones TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarServicios TO [gql_cliente];
GRANT EXECUTE ON OBJECT::dbo.ConsultarPromociones TO [gql_cliente];
GO

-- El rol de empleados puede ejecutar los CRUD, pero no recibe permisos directos
-- sobre las tablas. Toda operación queda obligada a pasar por un procedimiento.
DECLARE @sql nvarchar(max) = N'';
SELECT @sql += N'GRANT EXECUTE ON OBJECT::' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N' TO [gql_empleado];' + CHAR(13)
FROM sys.procedures
WHERE name LIKE N'Insertar%' OR name LIKE N'Actualizar%' OR name LIKE N'Eliminar%' OR name LIKE N'Consultar%' OR name = N'usp_ValidarLogin';
EXEC sys.sp_executesql @sql;
GO

SELECT r.name AS Rol, m.name AS Miembro
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = drm.member_principal_id
WHERE r.name LIKE N'gql_%'
ORDER BY r.name, m.name;
GO
