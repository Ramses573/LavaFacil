# Revisión local — 27 de octubre de 2026

> Actualización de preparación: consultar [MATRIZ_RACHEL.md](MATRIZ_RACHEL.md)
> para el estado vigente. Se corrigieron solo los dos métodos incompatibles de
> Pagos; Rachel valida con cero errores y el alcance global conserva dos de
> Recolecciones. Se agregaron comandos BCP, SELECT, carpetas de evidencia,
> consultas GraphQL por ID y pruebas locales. DbGateway ya utiliza la cadena
> Cliente en lecturas públicas autenticadas. El diagnóstico siguiente se conserva
> como registro inicial; no describe todas las correcciones posteriores.

## Git y alcance

La rama inicial era main, sin cambios locales, un commit detrás de origin/main.
Después de consultar GitHub se actualizó por fast-forward de dce8c10 a 2ff0797
(RAMSES: Agregar Proyecto 2 con API GraphQL y carga masiva). No hubo conflictos.
Esta preparación agrega archivos; no reemplaza los archivos entregados por Ramsés.
No se ejecutó BCP, SQL ni conexión a la base compartida.

## Lo preparado

- Diez CSV, tres filas por archivo, IDs 2001–2003. Los encabezados y su orden
  coinciden con las tablas del script base; las FK entre los CSV tienen destino.
- Script de reconstrucción con datos base, procedimientos y dos triggers. Su
  protección exige una base vacía y modo SQLCMD; no corresponde ejecutarlo sobre
  la base compartida existente.
- Mejoras incrementales, roles GraphQL y verificación por conteos/objetos.
- GraphQL: once consultas (incluido estado), login y treinta mutaciones CRUD,
  modelos para diez tablas, permisos de empleado/administrador y consultas públicas.
- Guías, manual DOCX/PDF y generador de manual; plantilla de evidencias. No hay
  capturas reales de Proyecto2. El manual describe resultados previos del autor,
  no demuestra que esta copia limpia esté validada contra la base real.

## Bloqueos encontrados

1. Falta DbGateway en Git: Program, Query y Mutation lo referencian. La regla
   global `**/Data/` excluye una carpeta con ese nombre. Se agregó una implementación
   en `Infrastructure/DbGateway.cs`, conservando el namespace esperado y los
   resolvers originales. Usa procedimientos y parámetros, conexión Invitado para
   login/público y Empleado después de RequireStaff. La conexión Cliente queda
   reservada: aún no existen operaciones de autoservicio del cliente.
2. Pagos: ID 2002 usa SINPE y 2003 Tarjeta. El CHECK solo permite Efectivo y
   SINPE Movil. Propuesta para Rachel: SINPE → SINPE Movil; elegir un método
   admitido para 2003 según el caso de prueba. No se alteraron los CSV originales.
3. Recolecciones de Ramsés: IDs 2002/2003 usan En camino/Completada; el CHECK
   permite Pendiente, Programada, Recolectada y Cancelada. Coordinar la corrección
   con Ramsés; no ampliar restricciones ni cambiar sus datos silenciosamente.
4. Los comandos BCP de la guía omiten CHECK_CONSTRAINTS y FIRE_TRIGGERS. Antes
   de una ejecución futura revisar `-h "CHECK_CONSTRAINTS,FIRE_TRIGGERS"`, permisos
   necesarios y terminadores reales de archivo. Sin esas opciones puede omitirse
   validación importante. No se generó un ejecutor automático de cargas.
5. Usuarios recibe ClaveHash nullable al aplicar mejoras: su CSV tiene el formato
   del esquema base. El asistente debe mapear columnas explícitamente y dejar
   ClaveHash NULL. Las tres cuentas CSV están inactivas: no sirven para demostrar
   login exitoso sin una preparación coordinada de cuentas de prueba.
6. Login GraphQL usa usp_ValidarLogin (Clave), mientras la aplicación web tiene
   procedimientos de ClaveHash. Verificar compatibilidad con las cuentas reales.
   El token no tiene caducidad explícita y las mutaciones devuelven ex.Message;
   son pendientes de seguridad antes de exponer la API fuera del laboratorio.
7. El script 04 enumera objetos y conteos; no prueba por sí solo IDs importados,
   valores exactos, integridad, permisos efectivos ni sincronización del mirror.

## Preparación agregada y uso inmediato

Ejecutar desde la raíz del repositorio:

```powershell
python Proyecto2/02-Datos-Carga/Rachel-BCP/validar_csv.py
dotnet build Proyecto2/03-Backend-GraphQL/LavaFacil.GraphQL -c Release
```

El validador solo lee archivos, comprueba encabezados/orden, tres filas, IDs,
listas CHECK simples y referencias entre los diez CSV. Devuelve código 1 ante
incompatibilidades (actualmente cuatro). No valida todos los CHECK, tipos,
longitudes, triggers ni el estado del servidor. No sustituye una prueba SQL.

Podemos trabajar ya en validación local, correcciones propuestas de los CSV de
Rachel, pruebas del esquema GraphQL sin datos y organización de evidencias.
La clase nueva puede compilarse sin cadenas de conexión: no abre conexiones
hasta que un resolver solicita datos.

Validación realizada: `dotnet build -c Release -p:NuGetAudit=false` terminó con
cero errores y cero advertencias después de restaurar dependencias. Esto valida
compilación; aún faltan ejecución del esquema/endpoint y pruebas de integración.
El validador local detectó las cuatro incompatibilidades descritas. Los archivos
preexistentes versionados quedaron sin diferencias respecto a origin/main.

## Pendiente para la sesión coordinada real

- Confirmar principal, mirroring y disponibilidad de IDs y claves únicas contra
  el servidor; el rango libre en los CSV no demuestra que esté libre en SQL.
- Verificar qué scripts/mejoras ya están aplicados; no reconstruir la base actual.
- Acordar correcciones de datos y opciones de importación con Ramsés.
- Configurar credenciales privadas y logins/SID en ambas instancias.
- Cargar por pasos intercalados 1–10; antes de Pagos esperar DetallePedido y
  verificar los totales mantenidos por trigger.
- Capturar filas/consultas reales, demostrar roles y CRUD, coordinar failover y
  regenerar desde SSMS el script final con esquema y datos al terminar.

Referencias técnicas: [BCP, hints y restricciones](https://learn.microsoft.com/sql/tools/bcp-utility?view=sql-server-ver17),
[inyección de servicios Hot Chocolate](https://chillicream.com/docs/hotchocolate/resolvers/dependency-injection).
