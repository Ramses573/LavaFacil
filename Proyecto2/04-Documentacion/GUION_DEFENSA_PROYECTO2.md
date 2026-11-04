# Guión de Defensa Técnica - Proyecto 2: LavaFácil
**Curso:** TI-156 Bases de Datos Avanzadas
**Equipo:** Rachel Rosales & José Ramsés Aguilar
**Fecha:** Miércoles 4 de noviembre de 2026
**Duración recomendada:** 5 a 7 minutos

---

## 📌 Datos Clave para la Demostración

* **URL GraphQL (Banana Cake Pop):** `http://localhost:5125/graphql`
* **Base de Datos:** `LavaFacil` (SQL Server)
* **Credenciales de prueba disponibles en vivo:**
  * **Administrador de prueba:** `admin_p2_01` / `DemoTemporal2026!3`. Las credenciales personales se introducen de forma privada.
  * **Empleado:** `empleado_p2_01` / `DemoTemporal2026!2`
  * **Cliente:** `cliente_p2_01` / `DemoTemporal2026!1`

---

## 🎭 Dinámica General de la Presentación

* **Quién proyecta:** Ramsés (tiene el backend y SSMS abiertos y listos en la laptop).
* **Intervenciones:** Rachel arranca con la introducción y BCP; Ramsés toma la palabra con SSMS y seguridad; y ambos cierran demostrando las pruebas de GraphQL en vivo.
* **Tono:** Técnico, directo y conciso. No hablar de teoría genérica; ir directo a mostrar el software funcionando y la base de datos.

---

## 🎬 Paso a Paso: Guión Minuto a Minuto

---

### Acto 1: Introducción y Cargas Masivas con BCP
**Voz principal: Rachel** *(Ramsés proyecta el manual técnico o la carpeta de archivos)*

> **Rachel:**
> «Buenos días, profe. Para este segundo avance del proyecto LavaFácil implementamos la carga masiva de datos en nuestras 10 tablas, el esquema de seguridad por roles a nivel de SQL Server y un backend completo en GraphQL con operaciones CRUD soportadas 100% en Procedimientos Almacenados.
>
> En la primera parte, nos dividimos las 10 tablas en dos bloques de 5 para utilizar las dos herramientas exigidas: **BCP** y el **Asistente de Importación de SSMS**.
>
> A mí me correspondió la carga masiva mediante la utilidad de línea de comandos **BCP** para las tablas: **Clientes, Servicios, Promociones, Pedidos y Pagos**.
>
> **Puntos técnicos clave que resolvimos con BCP:**
> 1. Estructuramos los archivos en formato CSV utilizando delimitador por punto y coma (`;`), codificación UTF-8 y formatos de fecha estándar ISO (`YYYY-MM-DD`).
> 2. Respetamos rigurosamente la **integridad referencial (FK)**: cargamos primero las tablas maestras e independientes (*Clientes y Servicios*), luego las tablas intermedias (*Promociones y Pedidos*) y finalmente la tabla dependiente (*Pagos*).
> 3. En cada una de las 5 tablas insertamos los registros de prueba con identificadores de rango `2001`, `2002` y `2003`, obteniendo en consola el mensaje exitoso de `3 rows copied` sin violar restricciones de CHECK ni tipos de datos.»

*(Rachel le da el pase a Ramsés)*:
> **Rachel:**
> «Ahora mi compañero Ramsés les va a mostrar las cargas con el Asistente de SSMS y la arquitectura de seguridad.»

---

### Acto 2: Carga Masiva con SSMS y Modelo de Seguridad
**Voz principal: Ramsés** *(Ramsés proyecta SSMS y el script de seguridad)*

> **Ramsés:**
> «Gracias, Rachel. Por mi parte, realicé la carga masiva de las otras 5 tablas utilizando el **Asistente de Importación y Exportación de SQL Server (SSMS)**: **Empleados, Inventario, Usuarios, Recolecciones y DetallePedido**.
>
> **Detalles importantes de la carga con SSMS:**
> 1. Para las tablas que manejan columnas autoincrementales (*IDENTITY*), en el asistente configuramos la opción de **Habilitar inserción de identidad (Enable identity insert)** para conservar intactos los identificadores `2001` a `2003`.
> 2. Al igual que con BCP, se validaron previamente las restricciones; por ejemplo, en la tabla `Recolecciones`, ajustamos los estados válidos según el CHECK definido en el diseño de base de datos.
>
> **Arquitectura de Seguridad en Base de Datos:**
> Atendiendo al requerimiento de seguridad, creamos tres roles de base de datos con el principio de mínimo privilegio:
> * `gql_invitado`: Solo tiene permiso `EXECUTE` para autenticarse (`usp_ValidarLogin`) y consultar servicios y promociones públicas.
> * `gql_cliente`: Permite consultas de catálogo y estado propio.
> * `gql_empleado`: Tiene permisos de ejecución sobre los Stored Procedures de operaciones CRUD y gestión interna.
>
> **Regla de oro:** Ningún rol ni usuario tiene permisos directos (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) sobre las tablas físicas. Toda interacción está obligada a ejecutarse a través de Procedimientos Almacenados.»

---

### Acto 3: Demostración en Vivo de GraphQL
**Voz compartida: Ramsés y Rachel** *(Ramsés en el navegador en `http://localhost:5125/graphql`)*

> **Ramsés:**
> «Pasando a la segunda parte, construimos el backend utilizando **ASP.NET Core con Hot Chocolate GraphQL**. Vamos a demostrar el flujo completo en vivo:»

#### Paso 1: Validación de Login y Rol (Demuestra Ramsés)
*En la consola de Banana Cake Pop, Ramsés ejecuta:*
```graphql
mutation {
  login(usuario: "admin_p2_01", clave: "DemoTemporal2026!3") {
    exito
    mensaje
    rol
    idUsuario
    token
  }
}
```
> **Ramsés:**
> «Aquí invocamos la mutación `login`. Por detrás se ejecuta el SP `usp_ValidarLogin`, el cual valida que la clave coincida en binario y que el usuario y su empleado asociado estén activos. Como ven, el servicio retorna `exito: true`, el rol `Administrador` y un token JWT de sesión.»
> *(Opcional: cambiar el usuario a `cliente_p2_01` con clave `DemoTemporal2026!1` para que la profe vea que retorna rol `Cliente`).*

#### Paso 2: Consulta Protegida Multi-tabla (Demuestra Rachel)
*Ramsés copia el token en la pestaña **Headers**:*
`Authorization: Bearer <TOKEN>`

*Rachel guía la consulta:*
```graphql
query {
  clientes { idCliente nombre apellidos }
  servicios { idServicio nombreServicio precioBase }
  pedidos { idPedido total estado }
}
```
> **Rachel:**
> «Al agregar el token generado en el encabezado `Authorization`, podemos consultar los datos protegidos. En una sola petición GraphQL, el backend resuelve tres entidades distintas invocando los procedimientos almacenados de consulta correspondientes en SQL Server, evitando el problema del over-fetching de REST.»

#### Paso 3: Operación CRUD en Vivo (Demuestra Ramsés)
*Ramsés ejecuta la inserción de un nuevo servicio:*
```graphql
mutation {
  insertarServicio(
    nombreServicio: "Lavado Express Prueba Clase"
    descripcion: "Prueba de defensa de proyecto"
    tipoCobro: "Unidad"
    precioBase: 3500
    cantidadIncluida: 1
    precioAdicional: 0
  ) {
    exito
    mensaje
  }
}
```
> **Ramsés:**
> «Ejecutamos la mutación de inserción. Nos devuelve éxito. Ahora vamos a SSMS y corremos un `SELECT TOP 5 * FROM Servicios ORDER BY IdServicio DESC`: aquí vemos el registro creado con el ID autoincremental.»
>
> «De igual forma, el API tiene implementadas las mutaciones de actualización y eliminación para las 10 tablas del sistema.»

---

### Acto 4: Cierre Formal
**Voz principal: Rachel**

> **Rachel:**
> «Para finalizar, confirmamos la entrega en el canal de Teams con los cuatro elementos solicitados:
> 1. El script final unificado con estructura, datos, triggers, SPs y seguridad.
> 2. Los 10 archivos CSV originales.
> 3. El código fuente completo del backend GraphQL.
> 4. El manual técnico consolidado en PDF y Word con las 39 capturas de evidencia de todas las tablas y servicios.
> Quedamos atentos a cualquier consulta de la profesora. ¡Muchas gracias!»

---

## 🛡️ Preguntas Trampa Frecuentes y Cómo Defenderlas

### 1. «¿Por qué decidieron usar GraphQL en lugar de una API REST tradicional?»
* **Respuesta (Rachel o Ramsés):**
  *«Profe, el requerimiento del proyecto pedía expresamente GraphQL, pero a nivel arquitectónico ofrece una gran ventaja: el cliente solicita exactamente los campos que necesita de una o varias tablas en una sola petición HTTP. Esto evita el 'over-fetching' (traer datos innecesarios) y el 'under-fetching' (hacer múltiples llamadas REST para armar una sola pantalla de pedidos y clientes).»*

### 2. «¿Cómo manejan la seguridad para que un cliente no pueda modificar datos de empleados o inventario?»
* **Respuesta (Ramsés):**
  *«La seguridad está blindada en dos niveles. A nivel de aplicación, el backend valida el rol del token en cada mutación administrativa mediante `identity.RequireStaff()`. Y a nivel de base de datos, el `DbGateway` utiliza cadenas de conexión distintas con credenciales de SQL Server separadas: un usuario con rol `gql_cliente` ni siquiera tiene concedido el permiso `EXECUTE` sobre los procedimientos almacenados de mantenimiento de empleados o inventario.»*

### 3. «¿Por qué todos los CRUD pasan por Procedimientos Almacenados en vez de hacer INSERT o SELECT directo desde el backend?»
* **Respuesta (Rachel):**
  *«Por seguridad e integridad. Al revocar permisos directos sobre las tablas y conceder únicamente `EXECUTE` sobre los SPs, prevenimos inyección de SQL directa, desacoplamos la estructura física de la base de datos de la aplicación y encapsulamos reglas de negocio complejas dentro del propio motor.»*

### 4. «¿Qué orden siguieron para cargar las tablas y no tener errores de Foreign Keys?»
* **Respuesta (Rachel):**
  *«Seguimos estrictamente la jerarquía de dependencias: primero cargamos entidades maestras que no dependen de nadie (*Clientes, Empleados, Inventario, Servicios*), luego las entidades que las referencian (*Usuarios, Promociones, Pedidos*), y finalmente las de mayor nivel de dependencia (*Recolecciones, DetallePedido y Pagos*).»*

### 5. «¿Qué pasa si un usuario inactivo intenta loguearse en el sistema?»
* **Respuesta (Ramsés):**
  *«El procedimiento `usp_ValidarLogin` valida explícitamente `AND u.Activo = 1` y también corrobora que el cliente o empleado relacionado tenga su bandera de activo en 1. Si el usuario está deshabilitado, el SP devuelve `LoginValido = 0` y el backend rechaza la petición con 'Usuario o contraseña incorrectos', sin otorgar ningún token.»*
