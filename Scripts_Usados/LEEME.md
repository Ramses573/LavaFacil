# Scripts usados en LavaFacil

Recopilación del 11 de octubre de 2026. Son copias: no se movieron ni borraron los originales y no se modificó la base de datos.

## Contenido

- `01_Base_Original/Proyecto Script.sql`: script original adjuntado al proyecto; incluye estructuras y datos originales. No equivale a una copia de seguridad del estado actual.
- `02_Procedimientos_App`: scripts guardados de procedimientos complementarios, pruebas y cuenta inicial.
- `03_Objetos_Actuales/Objetos_Actuales.sql`: exportación directa de los procedimientos y los dos triggers instalados en MADRENZO/LavaFacil. Incluye `usp_ValidarLogin` y los procedimientos `app_*`. Contiene CREATE y separadores GO; fallará si se ejecuta sobre objetos que ya existen. No incluye datos, logins de servidor ni certificados.
- `04_Diagnosticos`: consultas guardadas para revisar el endpoint y el acceso de Rachel, más la consulta utilizada para exportar definiciones.
- `05_Pruebas_y_Limpieza/QaHarness`: código usado para generar datos temporales, comprobar las API, inspeccionar y eliminar exclusivamente los registros de esa prueba. No ejecutar sin revisar. El manifiesto antiguo se omitió: sus datos de prueba ya fueron eliminados. El modo seed genera un manifiesto nuevo; en el recorrido realizado se utilizó después repair-fixture-emails antes de probar los formularios. Las comprobaciones reflejan el escenario de pruebas de ese momento, no cualquier base con datos reales.
- `05_Pruebas_y_Limpieza/Verification`: ejecutor de consultas SQL usado para diagnósticos. Requiere la configuración local cifrada del aplicativo y recibe la ruta de LavaFacil y la del SQL como argumentos.
- `06_Aplicativo`: copias del código del servidor, JavaScript, archivo de proyecto y arranque. Para iniciar normalmente, utilizar Iniciar.cmd de la carpeta principal de LavaFacil, no esta copia dentro del archivo histórico.
- `07_Resultados`: evidencias JSON de las comprobaciones y limpieza ya realizadas.

## Advertencias

No ejecutar todos los archivos consecutivamente. Los scripts de creación, pruebas y limpieza tienen propósitos distintos; pueden insertar o eliminar datos si se ejecutan.

No se incluyó `connection.dpapi`, contraseñas de conexión, archivos bin/obj ni el manifiesto con credenciales temporales de las pruebas. El código del ejecutor utiliza la configuración cifrada existente en este equipo; no es una configuración transferible para Rachel.

Esta carpeta reúne los scripts que quedaron guardados y las definiciones que se pudieron recuperar directamente de la base. No se encontró un archivo original guardado para cada comando ejecutado anteriormente de firewall, respaldos, creación de logins y certificados/endpoint; por eso no se inventaron ni se presentaron reconstrucciones como scripts usados. La configuración del espejo de Rachel continúa pendiente y no se incluye como trabajo realizado.
