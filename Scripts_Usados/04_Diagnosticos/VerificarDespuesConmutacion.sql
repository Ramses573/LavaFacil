USE LavaFacil;
SELECT @@SERVERNAME AS ServidorConectado,DB_NAME() AS BaseActual,ORIGINAL_LOGIN() AS LoginSQL;
SELECT mirroring_role_desc AS Rol,mirroring_state_desc AS Estado,mirroring_partner_name AS Companero,mirroring_safety_level_desc AS Seguridad
FROM sys.database_mirroring WHERE database_id=DB_ID();
SELECT NombreUsuario,TipoUsuario,Activo FROM dbo.Usuarios WHERE NombreUsuario=N'ramses.aguilar';
