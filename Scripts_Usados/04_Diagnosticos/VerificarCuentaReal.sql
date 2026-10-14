USE LavaFacil;
SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual;
SELECT NombreUsuario,TipoUsuario,Activo FROM dbo.Usuarios WHERE NombreUsuario=N'ramses.aguilar';
SELECT mirroring_role_desc AS Rol,mirroring_state_desc AS Estado FROM sys.database_mirroring WHERE database_id=DB_ID();
