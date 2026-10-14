# Prueba de conmutación manual — 11 de octubre de 2026

## Resultado

El aplicativo conservó la sesión administradora y pudo consultar servicios, registrar un cliente ficticio y consultar el perfil mientras Rachel era principal. Failover Partner dirigió las conexiones a LAPTOP-D0TECCJR\LAVAFACIL2022. La consulta de servicios terminó correctamente pero no había servicios activos registrados.

La conmutación de ida ya había sido realizada cuando se intentó ejecutar el script protegido desde esta sesión. La comprobación impidió repetirla porque la conexión ya llegaba al servidor de Rachel. No atribuir a ese script la ejecución de la primera conmutación.

Se ejecutó correctamente la conmutación manual de regreso desde Rachel, tras comprobar PRINCIPAL, SYNCHRONIZED y FULL. Una conexión nueva confirmó MADRENZO como PRINCIPAL y SYNCHRONIZED, y la interfaz mostró el cambio de servidor sin cambiar manualmente la cadena de conexión.

Se eliminó únicamente el cliente temporal IdCliente=7, validando además cédula QA-FAILOVER-20261011, nombre Prueba Conmutacion, apellidos Cliente Ficticio, teléfono 00000000, correo failover-20261011@example.test y dirección de prueba. Se verificaron cero coincidencias restantes. La cuenta ramses.aguilar sigue activa como Administrador. La eliminación no tiene deshacer en el aplicativo; los datos ficticios están documentados aquí y en la captura para poder recrearlos si fuera necesario.

Estado final verificado: MADRENZO / LavaFacil / PRINCIPAL / SYNCHRONIZED / FULL. No se apagaron servicios, no se forzó pérdida de datos ni se configuró un testigo. Esta es una prueba de conmutación MANUAL, no evidencia de failover automático ante una caída.

## Capturas

1. 01-Antes-MADRENZO.jpg: aplicativo conectado al principal original.
2. 02-Despues-Rachel.jpg: aplicativo conectado a Rachel y contador de cliente ficticio.
3. 03-Servicios-Rachel.jpg: consulta de servicios completada, sin servicios activos.
4. 04-Cliente-Rachel.jpg: registro ficticio visible en la base atendida por Rachel.
5. 05-Perfil-Rachel.jpg: perfil real conservado; contiene información personal, compartir solamente para el proyecto.
6. 06-Regreso-MADRENZO.jpg: aplicativo muestra reconexión a MADRENZO y conserva el registro creado en Rachel.
7. 07-Cliente-Prueba-Eliminado.jpg: consulta en MADRENZO sin cliente ficticio.
8. 08-Final-MADRENZO.jpg: estado final del aplicativo en MADRENZO, con cero clientes tras la limpieza.

Las capturas son del aplicativo real. No se grabó un video desde esta sesión; Rachel realizaba su grabación. Falta verificar el archivo de video y completar el manual, datos y requisitos del proyecto.
