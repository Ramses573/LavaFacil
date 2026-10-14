SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BasePrueba, ORIGINAL_LOGIN() AS LoginActual,
 CONVERT(VARCHAR(172),SUSER_SID(),1) AS SID_Login,
 SERVERPROPERTY('IsIntegratedSecurityOnly') AS SoloWindows;
