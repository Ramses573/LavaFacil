SELECT IdPedido,Tipo,Estado,Intentos,Destino,DatosJson FROM dbo.CorreoEnvios WHERE IdPedido=18 FOR JSON AUTO;
