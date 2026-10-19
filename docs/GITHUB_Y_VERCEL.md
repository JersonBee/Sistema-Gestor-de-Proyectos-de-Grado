# Entrega manual: GitHub y Vercel

La publicación la realiza el usuario. No se han creado repositorios ni desplegado servicios remotos. La aplicación se entrega como MVC con JSP/JSTL, PostgreSQL y Tomcat dentro de Docker; no necesita Node.js ni un directorio de salida estático.

## 1. Preparar la copia para GitHub

Desde la raíz del proyecto, con Python 3 y Git disponibles:

```powershell
python scripts/preparar_entrega.py
```

Genera `entrega/proyectos-grado-fuentes.zip` y un manifiesto con SHA-256. Incluye fuentes, SQL, documentación, Maven Wrapper y Docker; excluye `.env`, herramientas locales, pruebas generadas, compilados, logs y metadatos Git/Vercel. Comprueba que los valores secretos locales no aparezcan en los archivos seleccionados. No ejecuta migraciones ni publica nada.

Para cargar desde el navegador de GitHub, descomprimir el ZIP y subir **su contenido**, incluidos los archivos y directorios cuyo nombre comienza con punto. `Dockerfile.vercel`, `pom.xml` y `mvnw` deben quedar en la raíz del repositorio, sin una carpeta envolvente. Crear un repositorio vacío, sin licencia elegida automáticamente.

También se puede subir desde esta carpeta con Git. Revisar antes de confirmar:

```powershell
git status --short
git add .
git diff --cached --stat
git commit -m "Entrega del sistema de proyectos de grado"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
git push -u origin main
```

Los comandos anteriores son instrucciones manuales: no se han ejecutado. Si ya existe `origin`, revisar `git remote -v` y reutilizarlo. No subir `.env` arrastrando la carpeta completa: una carga web no aplica `.gitignore`.

## 2. Importar en Vercel

1. Crear un proyecto e importar el repositorio GitHub.
2. Usar la raíz del repositorio como Root Directory.
3. Permitir la detección de `Dockerfile.vercel`. No configurar `npm install`, un build de Next.js ni una carpeta `public`/`dist`. Si se solicita framework, usar Other y conservar la construcción del contenedor.
4. Configurar las siguientes variables de ejecución antes de desplegar. Copiar los valores de la conexión local, sin incluir comillas externas ni subir `.env`.

| Variable | Valor |
| --- | --- |
| `PORT` | `8080` |
| `DB_JDBC_URL` | URL JDBC del Session Pooler de Supabase |
| `DB_USER` | Usuario exacto del pooler |
| `DB_PASSWORD` | Contraseña PostgreSQL local |

Plantilla de URL JDBC, sustituyendo el host por el de Connect → Session pooler:

```text
jdbc:postgresql://HOST_POOLER:5432/postgres?sslmode=verify-full&sslrootcert=/usr/local/tomcat/conf/ssl/supabase-ca.crt&connectTimeout=10&socketTimeout=20&currentSchema=grado
```

La CA pública ya está en la imagen. No utilizar la URL REST `https://...supabase.co`, una clave publishable ni una cadena `postgresql://` en `DB_JDBC_URL`. Se conserva la cuenta de conexión acordada para este trabajo de aula. Las variables no son argumentos de compilación y no deben escribirse en el Dockerfile.

5. Seleccionar Production para las credenciales reales. Habilitar Preview únicamente si se desea que esas ramas puedan acceder a esa misma base: los cambios de una vista previa también serán reales.
6. Desplegar y revisar los registros de construcción y arranque. Vercel construye Maven y Tomcat con sus dependencias; Compose y la base local de pruebas no se despliegan.

La [documentación oficial de Vercel](https://vercel.com/kb/guide/docker) describe la detección del Dockerfile, el puerto mediante `PORT` y el escalado a cero. Por esa detección no se añade un `vercel.json` con rutas estáticas que interfieran con JSP.

## 3. Base de datos existente

Supabase ya tiene las migraciones hasta `012_validacion_perfil_docente.sql`. **No repetir la instalación inicial**. El despliegue no ejecuta SQL automáticamente. Cron continúa en Supabase aunque la aplicación esté detenida.

Para una base completamente nueva, aplicar en orden los archivos de `database/`: 001, 002, 004, 006, 007, 008, 009, 010, 011, 012, 013, 014, 015, 016, 017 y 018. La 009 requiere pg_cron de Supabase. Los archivos de `database/supabase/` son auxiliares: leer sus encabezados y no ejecutarlos todos como si fueran migraciones nuevas.

Si aún no existe una cuenta del Comité, crear la primera con `scripts/crear-comite.ps1` usando el contenedor local conectado a la misma base. No hay cuenta administrativa predeterminada. Las cuentas existentes se mantienen.

## 4. Comprobación después de publicar

- Abrir `https://TU_DOMINIO/salud.jsp`: debe responder correctamente.
- Abrir `/`: debe mostrar el acceso; probar registro y entrada con una cuenta destinada a la demostración.
- Comprobar que `/panel.jsp` ofrece los módulos del rol y que salir devuelve al login.
- Verificar un proyecto existente, su resumen y las ventanas de fases.
- Revisar que las peticiones no produzcan errores JNDI/JDBC en los registros. No publicar registros que contengan datos personales.

### Error FUNCTION_INVOCATION_FAILED por puerto

Si Logs indica `could not connect to $PORT=80` y detecta `8005, 8080`, Vercel y Tomcat están usando puertos distintos. Configurar `PORT=8080` en **Production**, guardar y crear un nuevo despliegue. Agregar una variable no cambia los despliegues ya creados.

La imagen corregida utiliza `docker/iniciar.sh` para validar `PORT` y pasarlo al conector HTTP de Tomcat. Hay que subir tanto ese archivo como `Dockerfile.vercel` para incorporar la corrección; el valor por defecto local sigue siendo 8080. La declaración `EXPOSE` o `ENV` dentro de la imagen no sustituye la configuración del puerto del router en Vercel.

## Sesiones compartidas y orden de actualización

La migración `database/014_enlaces_adicionales_multilinea.sql` corrige la lectura de enlaces adicionales pegados en varias líneas: admite saltos CRLF de formularios HTML/Windows, LF y CR, líneas vacías y espacios/tabulaciones en los extremos. Reemplaza las funciones de presentación de Pago y propuesta/informe sin borrar datos ni cambiar sus firmas. En una base existente, aplicar solamente la 014 después de contar con las migraciones anteriores; no reinstalar 001. La 014 se aplicó y verificó en el Supabase de este proyecto el 19 de octubre de 2026. Para otros entornos debe aplicarse por separado: tener el archivo en Git no ejecuta la migración.

La migración `database/013_sesiones_http.sql` ya se aplicó y verificó en el Supabase de este proyecto el 19 de octubre de 2026. En otra base, aplicarla antes de desplegar esta versión. Es una migración aditiva: crea el almacén de sesiones y no modifica cuentas ni sus estados. No repetir 001/002. La instalación inicial nueva debe incluir también la 013 después de la 012.

Tomcat utiliza sus componentes incorporados PersistentManager, DataSourceStore y PersistentValve para guardar la sesión al terminar cada petición y restaurarla desde PostgreSQL en otra instancia. Incluye el token CSRF, el token de acceso y los mensajes temporales. No añade código Java, servlets ni DAOs propios. El cambio requiere subir `docker/context.xml`, `docker/iniciar.sh`, `Dockerfile.vercel` y las fuentes modificadas a GitHub antes del nuevo despliegue.

El timeout HTTP sigue siendo de 30 minutos de inactividad; el token de acceso tiene además un máximo absoluto de 8 horas y se revoca al cerrar sesión. Son límites distintos, no ocho horas de sesión HTTP garantizada. El proxy HTTPS se reconoce mediante RemoteIpValve para emitir cookies Secure cuando la petición procede de un proxy interno confiable; localmente HTTP sigue disponible. Se conservan HttpOnly y SameSite=Lax.

El almacén evita depender de afinidad para el recorrido secuencial entre instancias. PersistentValve coordina peticiones de la misma sesión dentro de cada instancia; no proporciona un bloqueo distribuido entre JVM. Formularios concurrentes de una misma sesión pueden competir por sus mensajes temporales. Las reglas de negocio y autorización continúan comprobándose en PostgreSQL. No se presenta esta configuración de aula como garantía de consistencia para escrituras de sesión simultáneas entre muchas instancias.

Las sesiones antiguas en memoria no se migran: después de actualizar puede ser necesario volver a entrar. Un formulario abierto antes de la actualización debe recargarse.

## Validación local previa

```powershell
.\mvnw.cmd -B -ntp package
python scripts/verificar_mvc.py
docker compose up --build -d
.\scripts\verificar.ps1
```

Las pruebas funcionales se documentan en `RESULTADO_PRUEBAS_ROLES.md`; se ejecutan exclusivamente contra la base local aislada. Publicar el repositorio no ejecuta esas pruebas contra Supabase.


## Validación de campos y listas docentes (015)

`database/015_validacion_espacios_perfil.sql` reemplaza las funciones de registro y administración para recortar tabulaciones y saltos de línea exteriores, rechazar nombres/perfiles obligatorios vacíos y omitir elementos vacíos de áreas y líneas. No cambia la autoactivación, las firmas ni los datos de cuentas existentes. Aplicar después de las migraciones anteriores; no reinstalar el esquema inicial. La migración 015 se aplicó y verificó en Supabase el 19 de octubre de 2026, conservando firmas, propietarios y permisos de las dos funciones.


## Validación de contenido de ideas (016)

`database/016_validacion_contenido_ideas.sql` reemplaza `proponer_idea` y `decidir_idea` para rechazar campos obligatorios y observaciones compuestos solo por espacios, tabulaciones o saltos de línea. Aplicar después de las migraciones anteriores, sin reinstalar el esquema. No modifica ideas existentes. Se aplicó y verificó en Supabase el 19 de octubre de 2026 conservando firmas, propietarios y permisos; otros entornos requieren ejecutar esta migración por separado.


## Validación de reportes y solicitudes (017)

`database/017_validacion_reportes_tramites.sql` reemplaza las funciones de decisión de Pago/revisión y creación/respuesta de solicitudes para rechazar textos obligatorios compuestos solo por espacios, tabulaciones o saltos. Aplicar después de las migraciones anteriores sin reinstalar el esquema. No limpia registros existentes. Se aplicó y verificó en Supabase el 19 de octubre de 2026, conservando firmas, propietarios y permisos de las cuatro funciones. Otros entornos requieren ejecutar la migración por separado.


## Validación de mensajes y actas (018)

`database/018_validacion_textos_comunicacion.sql` reemplaza `enviar_mensaje` y `crear_acta` para rechazar textos obligatorios compuestos solo por espacios, tabulaciones o saltos y conservar los saltos interiores de textos válidos. Aplicar después de las migraciones anteriores, sin reinstalar el esquema. No modifica registros existentes. Se aplicó y verificó en Supabase el 19 de octubre de 2026 conservando firmas, propietarios y permisos. Otros entornos deben ejecutarla por separado.
