# Instalación y ejecución del backend GraphQL

## 1. Preparar SQL Server

Crear tres logins SQL privados en la instancia principal: uno invitado, uno cliente y uno empleado. No guardar sus contraseñas en Git. En la base `LavaFacil` ejecutar `01-Script/03_Seguridad_GraphQL.sql` para crear los usuarios, roles y permisos de ejecución.

El login `lava_gql_invitado` solo valida credenciales y consulta servicios/promociones. El login `lava_gql_cliente` queda separado para operaciones autorizadas de clientes. El login `lava_gql_empleado` ejecuta los procedimientos CRUD. Ninguno necesita permisos directos sobre las tablas.

## 2. Configurar cadenas

Dentro de `03-Backend-GraphQL/LavaFacil.GraphQL`, copiar:

```powershell
Copy-Item appsettings.Development.example.json appsettings.Development.json
```

Editar únicamente el archivo nuevo y completar el servidor principal, `Initial Catalog=LavaFacil`, usuarios y contraseñas. Para este avance no se utiliza `Failover Partner`. El archivo real está excluido de Git.

## 3. Ejecutar

```powershell
dotnet restore
dotnet build -c Release
dotnet run
```

Abrir la URL indicada por la consola con `/graphql`, por ejemplo `http://localhost:5000/graphql`. Nitro permite ejecutar consultas y mutaciones y ver la documentación generada del esquema.

## 4. Autenticación

Ejecutar primero la mutación `login` de `PRUEBAS_GRAPHQL.md`. Copiar el token devuelto y configurar en Nitro el encabezado:

```json
{
  "Authorization": "Bearer TOKEN_COPIADO"
}
```

Las consultas públicas no requieren token. Las consultas administrativas y todas las mutaciones CRUD requieren rol `Empleado` o `Administrador`.

## 5. Comprobación final

Ejecutar primero `estado`, después el login, las consultas públicas, las consultas protegidas y una secuencia de insertar, actualizar y eliminar. Las tres conexiones deben usar la misma base `LavaFacil`, pero cada una conserva los permisos mínimos definidos para su rol.
