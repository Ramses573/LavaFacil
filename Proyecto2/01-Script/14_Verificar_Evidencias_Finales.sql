USE LavaFacil;
SET NOCOUNT ON;

SELECT 'Clientes' AS Tabla, CAST(IdCliente AS varchar(20)) AS Id,
       Cedula AS Referencia, CONCAT(Nombre, ' ', Apellidos) AS Descripcion
FROM EvidenciaBCPFinal20261117.Clientes
UNION ALL
SELECT 'Servicios', CAST(IdServicio AS varchar(20)), NombreServicio, Descripcion
FROM EvidenciaBCPFinal20261117.Servicios
UNION ALL
SELECT 'Promociones', CAST(IdPromocion AS varchar(20)), NombrePromocion,
       CONCAT('Descuento ', PorcentajeDescuento, '%')
FROM EvidenciaBCPFinal20261117.Promociones
UNION ALL
SELECT 'Pedidos', CAST(IdPedido AS varchar(20)), Estado, CONCAT('Total ', Total)
FROM EvidenciaBCPFinal20261117.Pedidos
UNION ALL
SELECT 'Pagos', CAST(IdPago AS varchar(20)), EstadoPago, CONCAT(MetodoPago, ' - ', Monto)
FROM EvidenciaBCPFinal20261117.Pagos
ORDER BY Tabla, Id;

