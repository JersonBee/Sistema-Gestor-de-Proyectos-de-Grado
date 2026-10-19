# Sistema de gestión de proyectos de grado

Aplicación JSP/JSTL con PostgreSQL en Supabase. Incluye acceso, perfiles, banco de ideas, creación de proyectos, Pago y revisiones de Propuesta/Informe. Hay versiones, previsualización, pausas, avisos y plazos automáticos. La fase Final permite registrar adicionales opcionales y cerrar por el Comité; las solicitudes permiten cambios de docentes, retiros y atención de consultas, quejas y reclamos. El historial muestra las decisiones y movimientos autorizados. Incluye actas con aprobación, mensajería privada estudiante/director, administración de cuentas por el Comité y búsqueda de proyectos con filtros combinables.

## Arquitectura MVC

El código está separado en `WEB-INF/modelo`, `WEB-INF/vistas` y `WEB-INF/controladores`. Los controladores son JSP/JSTL; las vistas contienen presentación sin SQL y el modelo conserva las consultas parametrizadas junto con las reglas de negocio de PostgreSQL. No se escriben servlets, DAOs ni scriptlets propios. Las rutas públicas existentes se mantienen como entradas a los controladores. La distribución y sus responsabilidades están en [Arquitectura MVC](docs/ARQUITECTURA_MVC.md).

## Versiones fijadas

| Componente | Versión |
| --- | --- |
| Java del contenedor | Eclipse Temurin 21, imagen fijada por digest |
| Tomcat | 11.0.27, imagen fijada por digest |
| Maven | 3.9.16 mediante Maven Wrapper y checksum SHA-256 |
| Jakarta JSTL API | 3.0.2 |
| Implementación JSTL | GlassFish 3.0.1 |
| JDBC PostgreSQL | 42.7.14 |

El contenedor incluye su Java y Tomcat. Maven descarga las bibliotecas declaradas y las empaqueta en `WEB-INF/lib` del WAR; el controlador JDBC se copia además al cargador común de Tomcat para el pool JNDI. No hay JAR manuales ni dependencias de bibliotecas instaladas en VS Code/XAMPP. La primera compilación necesita acceso a los repositorios oficiales. Actualizar los digests expresamente cuando se incorporen parches.

## Iniciar con Docker

Abrir Docker Desktop. Desde la raíz:

```powershell
Copy-Item .env.example .env
# Completar .env localmente con los datos de conexión del proyecto Supabase existente.
docker compose up --build -d
```

Abrir [http://localhost:8080](http://localhost:8080). Para detener:

```powershell
docker compose down
```

La dirección principal redirige a `/ingresar.jsp`. Tras iniciar sesión se abre `/panel.jsp`, el inicio privado con tarjetas de acceso según el rol. Quien no tiene cuenta puede abrir el registro desde el login; después de registrarse vuelve al acceso para ingresar. `/salud.jsp` no consulta la base. Registro, acceso y panel utilizan el recurso JNDI `jdbc/Grado`; registrar una cuenta escribe en Supabase. No se crean cuentas de prueba ni contraseñas de administración al iniciar el contenedor.

En el proyecto Supabase existente se aplicaron `006_acceso.sql`, `007_ideas_pago.sql`, `008_revisiones_plazos.sql`, `009_cron.sql` y `010_final_solicitudes.sql`. Para otra instalación aplicar primero `001_estructura.sql`, `002_catalogos.sql`, `004_utilidades.sql` y después las migraciones 006–010, en orden. La 009 requiere Supabase con pg_cron; las pruebas locales ejecutan directamente las funciones. No repetir los scripts iniciales en una base instalada. El ejecutor `scripts/aplicar-sql.ps1 -Archivo database/010_final_solicitudes.sql` usa las variables del contenedor sin mostrar credenciales. El recorrido nuevo está en `docs/CIERRE_Y_SOLICITUDES.md`.

Supabase ejecuta `grado.procesar_plazos()` cada minuto mediante el trabajo `grado-procesar-plazos`. Se verificó una ejecución real correcta con `database/supabase/03_verificar_cron.sql`. No depende de usuarios conectados ni del contenedor local. Las reglas, la pausa y los límites están descritos en `docs/REVISIONES_Y_PLAZOS.md`.

La migración `011_administracion_comunicacion.sql` también está aplicada en el proyecto Supabase existente. En otra instalación ejecutarla después de la 010. Añade las operaciones de actas, mensajes y cuentas sin borrar datos. El recorrido de las pantallas y permisos está en [Actas, mensajes, cuentas y búsqueda](docs/ACTAS_MENSAJES_CUENTAS.md).

## Primera cuenta del Comité

No hay autorregistro público del Comité ni contraseñas predeterminadas. Con Docker iniciado, ejecutar desde la raíz:

```powershell
.\scripts\crear-comite.ps1
```

El comando solicita nombre, correo y contraseña con confirmación; crea únicamente la primera cuenta del Comité, con hash bcrypt y auditoría. No modifica una cuenta existente y no guarda la contraseña en archivos. No se ha ejecutado contra Supabase: el usuario elige las credenciales al utilizarlo. El recorrido disponible se describe en `docs/FLUJO_IDEAS_PAGO.md`.

Usar una conexión JDBC de Supabase con TLS, puerto/usuario correctos según conexión directa o pooler. La conexión local usa Session Pooler y `sslmode=verify-full`, con la CA pública oficial en `docker/certs/supabase-ca.crt`. `currentSchema=grado` selecciona el esquema creado. Se conserva la cuenta de conexión suministrada, según lo acordado para el trabajo de aula. No usar las claves REST de Supabase como contraseña PostgreSQL. No compartir `.env`; el archivo está excluido de Git y del contexto Docker. El recurso de conexión se configura en el servidor, fuera del WAR.

## Compilar sin Docker

Requiere un JDK 21 y `JAVA_HOME` apuntando a él; no hace falta instalar Maven:

```powershell
.\mvnw.cmd -B -ntp package
```

En Linux/macOS: `./mvnw -B -ntp package`. El resultado es `target/proyectos-grado.war`. Para Tomcat externo usar la versión 11 indicada y copiar también `target/tomcat-lib/postgresql-42.7.14.jar` a su directorio `lib`; configurar el recurso JNDI y la sustitución de variables como en `docker/context.xml` y `Dockerfile.vercel`. No usar un Tomcat antiguo de XAMPP con bibliotecas `javax.servlet`: esta aplicación utiliza Jakarta.

Las bibliotecas del contenedor implementan internamente servlets como parte de JSP; no se escriben servlets, DAOs, clases Java, scriptlets ni JSPF propios. `web.xml` impide ejecutar scriptlets. No hay JavaScript en esta base.

## Verificación

Con la aplicación iniciada:

```powershell
.\scripts\verificar.ps1
```

El script revisa el WAR, las restricciones de vistas, la respuesta JSTL de salud y la entrada al login. El formulario de acceso realiza consultas mediante JNDI; la comprobación no ejecuta migraciones ni modifica datos académicos.

Las pruebas funcionales adicionales se ejecutan con Python 3 y Docker:

```powershell
python scripts/pruebas_acceso.py
# Suite completa del flujo inicial, incluyendo las pruebas de acceso:
python scripts/pruebas_flujo_inicial.py
# Suite integral, incluidos los módulos anteriores y los límites de tiempo:
python scripts/pruebas_revisiones.py
# Suite integral más entregables, cierre y solicitudes:
python scripts/pruebas_final_solicitudes.py
# Suite completa, incluidas actas, mensajes, cuentas y filtros:
python scripts/pruebas_comunicacion.py
# Suite completa con resumen durante las transiciones reales:
python scripts/pruebas_resumen.py
# Suite completa con bandeja de tareas por rol:
python scripts/pruebas_tareas.py
# Verificación ampliada: flujos, cinco roles, registro y paginación:
python -u scripts/pruebas_completas.py
```

Los scripts usan el proyecto Compose independiente `grado-pruebas` y el puerto 8082; no leen `.env` ni conectan a Supabase. Recrean exclusivamente su esquema de pruebas local. La suite integral comprueba acceso, ideas, Pago, reserva concurrente, asignación, cadena de revisiones, rechazos, versiones, acceso a previsualización y avisos privados. Un reloj controlado comprueba los límites de 3/5/90/180 días, la idempotencia y la pausa de revisión/espera/vigencia/corrección. Para detener ese entorno: `docker compose -p grado-pruebas -f compose.pruebas.yaml down`.

La imagen Docker se construyó y ejecutó con usuario sin privilegios de root. Registro y acceso respondieron HTTP 200 usando la conexión real a Supabase. Los resultados están registrados en `docs/VALIDACION_ENTORNO.md`.

## Resumen y cobertura

La verificación ampliada y su defecto corregido están documentados en [Resultado de pruebas por rol](docs/RESULTADO_PRUEBAS_ROLES.md). `012_validacion_perfil_docente.sql` está aplicada en Supabase; para otra instalación ejecutarla después de la 011. Evita registrar docentes con listas de áreas o líneas sin valores reales y no altera cuentas existentes.

El detalle del proyecto ofrece **Ver resumen y siguiente paso**: fase actual, responsable, documentos pendientes, plazos y estado. La indicación cambia con Pago, revisión, corrección, espera de Informe I, pausa y cierre. Véanse [Resumen del proyecto](docs/RESUMEN_PROYECTO.md) y [Cobertura del alcance](docs/COBERTURA_FUNCIONAL.md).

## Tareas por rol

El inicio presenta hasta seis tareas y **Mis tareas** abre la bandeja completa con veinte por página. Prioriza las revisiones con plazo e incluye entregas, decisiones del Comité y mensajes propios sin leer. La lista respeta asignaciones, pausas y estados del proyecto. Véase [Bandeja de tareas](docs/TAREAS_POR_ROL.md).

## Base visual

La aplicación utiliza `assets/img/marca-uts.svg`, una recreación vectorial a partir de la referencia proporcionada; la captura original se conserva como referencia y ya no se muestra. El verde institucional es `#C7D309`, acompañado de blancos y grises. El tema compartido `assets/css/administracion.css` define la presentación administrativa: navegación compacta, iconos SVG, botones, formularios y paneles. No requiere bibliotecas visuales, fuentes externas ni JavaScript. Las pantallas conservan navegación por teclado y adaptación a móviles. La recreación no se presenta como un archivo oficial suministrado por la institución.

## Entrega manual para GitHub y Vercel

Seguir [la guía de publicación](docs/GITHUB_Y_VERCEL.md). `python scripts/preparar_entrega.py` genera un ZIP de fuentes sin `.env`, compilados ni herramientas locales. No publica nada. La guía incluye las variables, el orden de migraciones y la persistencia compartida de sesiones y sus límites de concurrencia.

## Despliegue previsto

`Dockerfile.vercel` deja preparada la imagen OCI para el runtime de contenedores de Vercel. Al configurar el proyecto usar `PORT=8080` y las variables `DB_JDBC_URL`, `DB_USER`, `DB_PASSWORD` como secretos de ejecución, nunca argumentos de construcción. No se ha creado repositorio ni despliegue remoto.

Las sesiones de autenticación se verifican en PostgreSQL mediante tokens aleatorios guardados como hash. El navegador conserva una cookie de sesión HttpOnly y SameSite=Lax; los formularios usan CSRF y las consultas parámetros. La sesión HTTP se persiste por petición en PostgreSQL mediante componentes nativos de Tomcat. Antes de actualizar, aplicar `database/013_sesiones_http.sql`; el procedimiento y los límites de concurrencia están en `docs/GITHUB_Y_VERCEL.md`. Los vencimientos se procesan en Supabase Cron, independientemente de las sesiones HTTP.

## Referencias técnicas

- [Tomcat 11 y sus requisitos](https://tomcat.apache.org/tomcat-11.0-doc/index.html).
- [Jakarta JSTL](https://jakarta.ee/specifications/tags/3.0/).
- [Controlador JDBC PostgreSQL](https://jdbc.postgresql.org/).
- [Contenedores en Vercel](https://vercel.com/docs/functions/runtimes/container).

Los acuerdos funcionales están en `docs/DECISIONES_FUNCIONALES.md`. Los scripts de instalación Supabase permanecen en `database/supabase/`; el usuario confirma que ya los ejecutó. No volver a ejecutarlos como migraciones.
