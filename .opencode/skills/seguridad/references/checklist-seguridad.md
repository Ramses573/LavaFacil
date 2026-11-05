# Checklist de seguridad

## Secretos

- [ ] Sin claves, tokens ni contraseñas en el código.
- [ ] `.env` fuera de git y con `.env.example` documentado.
- [ ] Cadenas de conexión por variables de entorno.
- [ ] Sin secretos en logs ni mensajes de error.

## Autenticación

- [ ] Contraseñas con hash fuerte y salt.
- [ ] Tokens con expiración y rotación.
- [ ] Cierre de sesión invalida el token.
- [ ] Sin credenciales por defecto.

## Autorización

- [ ] Cada endpoint valida autenticación.
- [ ] Cada recurso valida propiedad o rol.
- [ ] Sin IDOR (acceso por ID ajeno).
- [ ] Acciones administrativas protegidas.

## Inyección

- [ ] Consultas parametrizadas.
- [ ] Sin concatenación de entrada en SQL/comandos.
- [ ] Rutas y nombres de archivo validados.
- [ ] Plantillas con escape automático.

## Entradas y salidas

- [ ] Validación de tipo, longitud y formato.
- [ ] Límites de tamaño y tasa.
- [ ] Escape de salida según contexto (HTML, atributo, JS, URL).
- [ ] Errores genéricos al cliente, detalle solo en logs.

## Dependencias

- [ ] Sin vulnerabilidades críticas conocidas.
- [ ] Versiones fijadas y actualizadas.
- [ ] Sin paquetes abandonados en rutas críticas.

## Configuración

- [ ] CORS restringido.
- [ ] Cabeceras de seguridad.
- [ ] HTTPS en producción.
- [ ] Permisos mínimos de archivos y servicios.
