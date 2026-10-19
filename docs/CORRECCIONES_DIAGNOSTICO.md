# Correcciones del diagnóstico — 19 de octubre de 2026

## Sesiones y registro

Se mantiene la activación automática de estudiantes, directores y evaluadores. El registro público no permite crear Comité o Secretaría. No se añade aprobación manual, correo ni invitaciones.

La sesión HTTP ahora se guarda en `grado.sesion_http` con PersistentValve, PersistentManager y DataSourceStore de Tomcat. Se restaura al recibir la misma cookie en otra instancia y se guarda al terminar cada petición. CSRF y autenticación mantienen su validación existente. Se aceptan únicamente tipos básicos al deserializar los valores de sesión.

Se añadió la migración aditiva `013_sesiones_http.sql`, aplicada en Supabase mediante la conexión local guardada. No modifica cuentas ni registros académicos. El comprobador `database/supabase/06_verificar_sesiones_http.sql` verifica su estructura sin leer sesiones ni datos personales.

Fuentes oficiales: [persistencia por petición de Tomcat](https://tomcat.apache.org/tomcat-11.0-doc/config/valve.html#Persistent_Valve) y [almacén de sesiones con DataSource](https://tomcat.apache.org/tomcat-11.0-doc/config/manager.html).

## Diagnóstico y otros ajustes

- El guard POST registra método incorrecto, token ausente, sesión ausente o token distinto sin valores de entrada.
- Los registros de la aplicación salen por consola para que Vercel pueda recogerlos.
- El registro explica y rechaza contraseñas de más de 72 bytes UTF-8 antes de invocar la función de alta; no las trunca.
- RemoteIpValve reconoce HTTPS detrás de proxies internos confiables para que Tomcat marque la cookie Secure; se mantienen HttpOnly y SameSite=Lax.
- Se eliminaron marcadores de conflicto del README y se actualizaron las instrucciones de base y sesiones.

## Verificación

`scripts/pruebas_acceso.py` verifica instalación local, registro estudiantil/docente autoactivo, autenticación, CSRF, SQL parametrizado, rotación, acceso privado, cuentas inactivas y cierre de sesión.

`scripts/pruebas_sesiones_compartidas.py` inicia una segunda instancia contra la misma base local. Verifica formulario GET en A y POST en B, registro y login entre instancias, navegación alternada, conservación tras reinicio, logout entre instancias, CSRF inválido, límite UTF-8 y flags de cookie con proxy HTTPS.

La suite `scripts/pruebas_completas.py` incluye también esta prueba y terminó correctamente tras los cambios: flujos de los cinco roles, 729 comprobaciones adicionales de permisos, validación de registro, siete listados paginados y continuidad de sesión entre instancias. Toda la carga de prueba utiliza la base Docker aislada `grado_pruebas`, sin cuentas ficticias en Supabase.

## Publicación y límites

Subir los cambios a GitHub y permitir el nuevo despliegue de Vercel. No se ha hecho push ni desplegado remotamente desde esta corrección. Recargar formularios abiertos antes del despliegue e iniciar sesión de nuevo si procedían de la versión anterior.

La persistencia no proporciona un bloqueo distribuido entre dos JVM para peticiones simultáneas de la misma sesión. Las pruebas demuestran continuidad secuencial entre instancias y tras reinicio; no garantizan consistencia de mensajes temporales bajo escrituras simultáneas. Se conservan 30 minutos de inactividad HTTP y un máximo absoluto de 8 horas del token de acceso.

No se ha cambiado la cuenta técnica de conexión acordada para el aula, ni se han creado cuentas administrativas sin datos de una persona responsable. La política de retención de intentos/sesiones, el presupuesto global de conexiones y la rotación de la contraseña quedan separados de esta corrección. Se conservan enlaces HTTP/HTTPS y su apertura externa como exige el alcance.

## Acceso MCP

El servidor MCP de Vercel ofrece herramientas en esta sesión, pero `get_project` para el proyecto conocido devolvió 403 por falta de autorización al equipo `jerson-bee`. No hay CLI de Vercel disponible como alternativa local. No se han podido confirmar el commit productivo ni los logs actuales. La conexión debe estar autorizada para ese equipo; después se puede verificar el despliegue sin modificarlo.
