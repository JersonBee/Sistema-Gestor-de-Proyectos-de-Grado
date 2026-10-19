# Sistema Gestor de Proyectos de Grado

Documentación técnica y guion de comprobación funcional. Corte documental: **19 de octubre de 2026**.

Este documento describe la implementación del repositorio y el conjunto DEMO preparado. Los estados de los proyectos cambian al ejecutar las aprobaciones, correcciones y cierres del guion; las tablas de casos preparados no son una consulta en tiempo real.

## Contenido

1. [Qué se construyó](#1-qué-se-construyó).
2. [Herramientas y requerimientos](#2-herramientas-y-requerimientos).
3. [Base de datos y restricciones UNIQUE](#3-base-de-datos-y-restricciones-unique).
4. [Arquitectura de la aplicación](#4-arquitectura-de-la-aplicación).
5. [Estructura y archivos del proyecto](#5-estructura-y-archivos-del-proyecto).
6. [Recorrido de las peticiones](#6-recorrido-de-las-peticiones).
7. [Seguridad](#7-seguridad).
8. [Módulos y permisos](#8-módulos-y-permisos).
9. [Usuarios y proyectos de prueba](#9-usuarios-y-proyectos-de-prueba).
10. [Guion de demostración por roles](#10-guion-de-demostración-por-roles).
11. [Verificación técnica y límites](#11-verificación-técnica-y-límites).
12. [Diccionario de datos](#12-diccionario-de-datos).
13. [Recuperación de acceso](#13-recuperación-de-acceso).
14. [Casos alternos del guion](#14-casos-alternos-del-guion).

## 1. Qué se construyó

Una aplicación administrativa para gestionar trabajos de grado de las Unidades Tecnológicas de Santander: registro de cuentas, banco de ideas, conformación del proyecto, pago, asignación de docentes, presentación de documentos, revisiones, correcciones, seguimiento, solicitudes y cierre.

La interfaz utiliza blanco, gris y verde institucional, navegación lateral, un inicio con accesos según el usuario, formularios y listados con filtros. El logo y los iconos están en archivos SVG locales. Al abrir el aplicativo sin sesión se presenta el ingreso; desde allí se accede al registro o, después de autenticarse, al inicio del sistema.

### Flujo académico

```text
Idea aprobada → Reserva y participantes → Pago aprobado por Comité
→ Asignación de director y evaluador → Propuesta I: director
→ Propuesta II: evaluador y Comité → Informe I: director
→ Informe II: evaluador y Comité → Final → Cierre por Comité
```

Las seis fases son Pago, Propuesta I, Propuesta II, Informe I, Informe II y Final. La aprobación del director abre la fase II correspondiente; en ella actúan primero el evaluador y después el Comité.

Las modalidades son Desarrollo de software, Monografía, Emprendimiento y Proyecto de investigación. Un proyecto puede ser individual o tener dos estudiantes. Cada cuenta tiene un solo rol y cada estudiante puede tener una sola participación vigente en un proyecto.

El Comité aprueba el conjunto presentado, incluyendo el comprobante en Pago. En propuesta se presentan F-DC-124 y reporte de similitud; en informe, F-DC-125, F-DC-129 y reporte de similitud. Hay espacios para documentos adicionales opcionales. Un rechazo exige reenviar el conjunto completo y comenzar otra vez con el director, conservando entregas, versiones y reportes anteriores.

### Reglas de tiempo

| Regla | Comportamiento |
|---|---|
| Días calendario | Cuentan fines de semana y festivos; el último día termina a las 23:59, hora de Bogotá. |
| Revisión docente | Cinco días para revisar; el vencimiento devuelve el trámite al estudiante y exige reiniciar la cadena. |
| Corrección estudiantil | Tres días; al vencer se genera una alerta, pero se permite reenviar. |
| Inicio de Informe I | Desde esta fase se cuentan 90 días antes de presentar el informe y 180 días como límite de cancelación si no se logra la aprobación correspondiente. |
| Pausa del proyecto | Detiene los procedimientos y el cómputo efectivo de los plazos; la reanudación ajusta las fechas. |
| Procesamiento automático | Una tarea de Supabase Cron procesa vencimientos sin que haya usuarios conectados. |

El Comité no recibe el mismo vencimiento automático de cinco días de los docentes. Las notificaciones son internas; la aplicación no envía correos.

## 2. Herramientas y requerimientos

### Tecnologías configuradas

| Herramienta | Uso en el proyecto |
|---|---|
| Visual Studio Code | Edición y consulta del proyecto. |
| Java 21 | Entorno de ejecución del contenedor. |
| Apache Tomcat 11.0.27 | Ejecución de JSP y componentes nativos de sesión/pool. |
| Maven Wrapper 3.9.16 | Descarga de dependencias y construcción reproducible del WAR. |
| Jakarta JSTL API 3.0.2 / implementación 3.0.1 | Condiciones, bucles, formularios y consultas parametrizadas. |
| JSP, EL, HTML y CSS | Controladores de página y presentación. |
| PostgreSQL JDBC 42.7.14 | Comunicación de Tomcat con PostgreSQL. |
| PostgreSQL en Supabase | Datos, restricciones, funciones de negocio y sesiones. |
| Supabase Cron y pgcrypto | Vencimientos programados y funciones criptográficas. |
| Supabase Storage | Alojamiento de los archivos públicos usados como ejemplos DEMO. |
| Docker / Docker Compose | Construcción, ejecución y entorno aislado de pruebas. |
| GitHub y Vercel | Repositorio y despliegue conectado al repositorio. |
| Python y PowerShell | Comprobaciones, preparación y scripts de apoyo; no son el backend de la aplicación. |

Las versiones anteriores corresponden a los archivos de este repositorio; no indican la última versión disponible de cada producto.

### Restricciones académicas respetadas

Se utiliza MVC con controladores JSP/JSTL. No se escribieron servlets propios, DAOs, scriptlets ni clases Java de aplicación. No se requiere JavaScript para la navegación y los formularios. Los detalles de fases utilizan controles HTML nativos. JSTL es una biblioteca de etiquetas empleada dentro de archivos `.jsp`, no una extensión de archivo.

Tomcat convierte internamente las JSP en servlets: eso es parte de su funcionamiento, distinto de implementar un servlet propio en el proyecto.

### Requisitos para ejecutar

1. Docker Desktop con el motor iniciado, conexión a Internet para la primera construcción y acceso a PostgreSQL.
2. Variables `DB_JDBC_URL`, `DB_USER` y `DB_PASSWORD` configuradas en `.env` local o en el entorno del despliegue. Usar `.env.example` como plantilla, sin guardar secretos en Git.
3. Esquema `grado` instalado y migraciones aplicadas siguiendo la guía de despliegue. No volver a instalar el esquema inicial sobre la base que ya contiene los datos.
4. En Vercel, conservar la configuración del contenedor y `PORT=8080` indicada en la guía. El arranque de Tomcat toma el puerto de la variable `PORT`.

Desde la raíz del repositorio:

```powershell
docker compose up --build -d
```

La aplicación local queda en `http://localhost:8080/`. El entorno aislado de pruebas usa `http://127.0.0.1:8082/` y la base `grado_pruebas`; no debe confundirse con el contenedor conectado a Supabase.

Para construir únicamente el WAR, con Java disponible:

```powershell
.\mvnw.cmd package
```

El resultado es `target/proyectos-grado.war`. Las dependencias se empaquetan o instalan en la imagen; no se necesita un Maven global. Una instalación antigua de Tomcat incluida en XAMPP puede usar `javax` y no ser compatible con las dependencias Jakarta de esta aplicación.

Guía operativa: [GitHub y Vercel](docs/GITHUB_Y_VERCEL.md).

## 3. Base de datos y restricciones UNIQUE

### Organización y relaciones

Diagrama del esquema: [MER completo en PNG](docs/diagramas/MER_completo.png), [SVG ampliable](docs/diagramas/MER_completo.svg) y [vista general](docs/diagramas/MER_general.png). Consultar las [notas de cardinalidad y vigencia](docs/diagramas/README.md).

Motor PostgreSQL, esquema de aplicación `grado`. Los identificadores de entidades son generalmente `bigint` autogenerados; los catálogos estables utilizan códigos. Los eventos y vencimientos utilizan fechas con zona horaria (`timestamptz`).

| Grupo | Tablas | Responsabilidad |
|---|---|---|
| Cuentas | `rol`, `usuario`, `perfil_docente` | Identidad, rol único, estado, datos personales y formación docente. |
| Aptitud | `area_experiencia`, `modalidad`, `linea_investigacion`, `docente_area`, `docente_modalidad`, `docente_linea` | Varias especialidades por docente y criterios para asignarlo. |
| Ideas | `idea`, `decision_idea` | Autor, contenido, modalidad y decisiones del Comité. |
| Proyecto | `proyecto`, `participante_proyecto`, `asignacion_proyecto`, `pausa_proyecto` | Reserva, estudiantes, docentes e historial de pausas. |
| Fases | `fase`, `proyecto_fase` | Catálogo de fases y avance de cada proyecto. |
| Archivos | `tipo_documento`, `documento`, `documento_version` | Documento lógico y versiones de sus enlaces. |
| Evaluación | `entrega_revision`, `entrega_documento_version`, `ciclo_revision`, `revision_entrega`, `plazo_correccion` | Conjunto exacto presentado, decisiones y correcciones. |
| Datos especiales | `datos_pago`, `entrega_final` | Pago, preferencia de director y entregables finales. |
| Trámites | `solicitud`, `respuesta_solicitud`, `acta`, `acta_proyecto` | Cambios, retiros, consultas, decisiones y actas. |
| Comunicación | `mensaje`, `notificacion`, `evento_auditoria` | Mensajes privados, avisos y trazabilidad. |
| Acceso técnico | `sesion_acceso`, `intento_acceso`, `sesion_http` | Tokens, control de intentos y persistencia de sesiones Tomcat. |

La vista `docente_apto_idea` combina modalidad, área y línea de investigación. Un docente debe coincidir en los tres criterios y tener la cuenta activa. El formulario también separa el rol director del rol evaluador.

Una idea se relaciona con proyectos históricos, pero solo puede estar reservada por uno no cancelado. Cada proyecto conserva participantes y asignaciones anteriores con fechas de cierre. Una entrega apunta a versiones concretas: cambiar un enlace posteriormente no modifica lo que fue revisado en una entrega anterior.

### Qué significa UNIQUE

`PRIMARY KEY` identifica una fila; `FOREIGN KEY` comprueba su relación con otra tabla; `CHECK` valida una condición; `UNIQUE` impide repetir una clave de negocio. Los índices únicos parciales aplican esa exclusividad solamente a filas vigentes. Por eso es posible conservar un docente anterior sin tener dos directores activos simultáneamente.

### Restricciones únicas e índices de negocio

| Tabla / índice | Columnas o condición | Qué impide |
|---|---|---|
| `rol` | `nombre UNIQUE` | Dos nombres de rol iguales. |
| `usuario_correo_unico` | `lower(correo)` | Registrar el mismo correo cambiando mayúsculas/minúsculas. |
| `area_experiencia` | `nombre UNIQUE` | Duplicar un área del catálogo. |
| `modalidad` | `codigo UNIQUE`; `nombre UNIQUE` | Duplicar códigos o nombres de modalidad. |
| `linea_investigacion` | `nombre UNIQUE` | Duplicar líneas de investigación. |
| `proyecto_reserva_idea` | `idea_id`, si `estado <> 'cancelado'` | Reservar una misma idea en dos proyectos no cancelados. Un finalizado conserva su reserva. |
| `pausa_unica_abierta` | `proyecto_id`, si `fin_en IS NULL` | Dos pausas abiertas del mismo proyecto. |
| `participante_plaza_activa` | `(proyecto_id, plaza)`, si `retiro_en IS NULL` | Dos estudiantes ocupando la misma plaza vigente. |
| `participante_estudiante_activo` | `estudiante_id`, si `retiro_en IS NULL` | Un estudiante en dos proyectos vigentes. |
| `asignacion_funcion_activa` | `(proyecto_id, funcion)`, si `fin_en IS NULL` | Dos directores o dos evaluadores vigentes para el proyecto. |
| `asignacion_persona_distinta` | `(proyecto_id, docente_id)`, si `fin_en IS NULL` | Una misma persona como director y evaluador vigentes del proyecto. |
| `asignacion_proyecto` | `(id, proyecto_id) UNIQUE` | Ofrece una clave compuesta para relaciones que deben conservar el proyecto. |
| `fase` | `nombre UNIQUE`; `orden UNIQUE` | Fases con nombres u orden repetidos. |
| `proyecto_fase` | `(proyecto_id, fase_codigo) UNIQUE`; `(id, proyecto_id) UNIQUE` | Duplicar una fase del mismo proyecto y referenciarla sin su proyecto. |
| `proyecto_una_fase_en_curso` | `proyecto_id`, si iniciada y no finalizada | Dos fases abiertas simultáneamente. |
| `tipo_documento` | `nombre UNIQUE` | Duplicar un nombre de tipo documental. |
| `documento` | `(proyecto_fase_id, tipo_codigo, etiqueta) UNIQUE`; `(id, proyecto_id) UNIQUE` | Duplicar el documento lógico o perder su relación de proyecto. |
| `documento_institucional_unico` | `(proyecto_fase_id, tipo_codigo)`, si el tipo no es `adicional` | Dos documentos institucionales del mismo tipo en una fase. Las correcciones son versiones. |
| `documento_version` | `(documento_id, numero) UNIQUE`; `(id, documento_id) UNIQUE` | Repetir un número de versión o mezclar versiones de documentos distintos. |
| `entrega_revision` | `(fase_origen_id, numero) UNIQUE`; `(id, proyecto_id) UNIQUE` | Repetir el número de entrega de una fase o perder el proyecto asociado. |
| `ciclo_revision` | `(entrega_id, numero) UNIQUE` | Dos ciclos con el mismo número para una entrega. |
| `ciclo_revision_abierto` | `entrega_id`, si `finalizado_en IS NULL` | Dos ciclos abiertos para una misma entrega. |
| `revision_entrega` | `(ciclo_id, etapa) UNIQUE` | Duplicar una etapa de revisión en un ciclo. |
| `revision_una_pendiente_por_ciclo` | `ciclo_id`, si `decision IS NULL` | Dos revisores pendientes simultáneamente dentro del ciclo. |
| `plazo_correccion` | `revision_id UNIQUE`; `entrega_reenvio_id UNIQUE` | Duplicar el plazo de una revisión o asociar un reenvío a varios plazos. |
| `acta` | `numero UNIQUE` | Repetir el número institucional de acta. |
| `notificacion` | `(evento_id, destinatario_id) UNIQUE` | Generar dos avisos del mismo evento para la misma persona. |

### Claves primarias que también establecen exclusividad

| Tabla | Clave | Regla |
|---|---|---|
| `perfil_docente` | `usuario_id` | Un perfil docente por usuario. |
| `docente_area` | `(docente_id, area_id)` | Un vínculo por docente y área. |
| `docente_modalidad` | `(docente_id, modalidad_id)` | Un vínculo por docente y modalidad. |
| `docente_linea` | `(docente_id, linea_id)` | Un vínculo por docente y línea. |
| `entrega_documento_version` | `(entrega_id, documento_id)` | Una versión de cada documento dentro de una entrega. |
| `datos_pago` | `proyecto_id` | Un registro de datos de Pago por proyecto. |
| `entrega_final` | `proyecto_id` | Un registro de datos finales por proyecto. |
| `acta_proyecto` | `(acta_id, proyecto_id)` | Un vínculo por acta y proyecto. |
| `sesion_acceso` | `token_hash` | Tokens almacenados sin repetición de su hash. |
| `sesion_http` | `(id, aplicacion)` | Una sesión HTTP por identificador y aplicación. |

Las demás claves primarias identifican sus entidades mediante `id` o un código. En un `UNIQUE` normal de PostgreSQL los valores `NULL` no equivalen a un mismo valor repetido; por ejemplo, varios plazos pueden seguir sin `entrega_reenvio_id` mientras todavía no hay reenvío.

### Restricciones adicionales y reglas transaccionales

Las claves foráneas conservan la integridad entre cuentas, proyectos, entregas y versiones. Las claves compuestas impiden asociar una versión de otro documento o proyecto. Los `CHECK` restringen estados, fechas y plazas; las plazas 1 y 2, junto con su exclusividad, limitan el proyecto a dos participantes vigentes.

El rol único se representa con una columna `usuario.rol_codigo` que referencia a `rol`, no con una colección de roles. La aptitud docente, el pago anterior a la asignación, los permisos, la cadena de aprobación, las pausas y los vencimientos se verifican mediante funciones y triggers. No todas esas reglas se resuelven con `UNIQUE`.

Los archivos `001` a `015` documentan la evolución del esquema. `003` y `005` son comprobaciones; no son nuevas funcionalidades. `009_cron.sql` configura el procesamiento periódico y `013_sesiones_http.sql` añade la persistencia HTTP y `014_enlaces_adicionales_multilinea.sql` corrige los saltos de línea de los enlaces adicionales enviados desde formularios HTML. La 015 valida los textos obligatorios del registro y perfil docente ante tabulaciones y saltos de línea. Para el orden completo de instalación consultar la guía operativa, no ejecutar indiscriminadamente todos los archivos de `database/` sobre producción.

## 4. Arquitectura de la aplicación

Diagrama: [arquitectura en PNG](docs/diagramas/ARQUITECTURA.png) y [versión SVG ampliable](docs/diagramas/ARQUITECTURA.svg).

Se implementa **Modelo–Vista–Controlador mediante controladores de página JSP**.

| Capa | Ubicación | Responsabilidad |
|---|---|---|
| Entrada pública | JSP de la raíz web y `acciones/` | Incluye un controlador interno con una ruta constante. |
| Controlador | `WEB-INF/controladores/` | Comprueba sesión, rol, método, CSRF y parámetros; invoca modelo y selecciona vista o redirección. |
| Modelo de acceso | `WEB-INF/modelo/` | Ejecuta JSTL SQL con parámetros sobre el DataSource JNDI. |
| Negocio y persistencia | `database/`, PostgreSQL | Estados, autorizaciones de escritura, restricciones, transacciones, auditoría y plazos. |
| Vista | `WEB-INF/vistas/` | Presenta HTML y JSTL/EL con datos preparados y salida escapada. |
| Infraestructura | `docker/`, Tomcat, Supabase | Pool JDBC, HTTPS/proxy, sesión HTTP, contenedor y tareas programadas. |

```text
Navegador → JSP pública → Controlador → Modelo JSTL SQL → PostgreSQL
                              ↓                ↑
                         Vista HTML ← resultados
                              ↓
                          Navegador
```

No existe un servlet frontal propio. Los controladores de página cumplen la coordinación de MVC. Las vistas no consultan la base ni toman decisiones de autenticación; el modelo no genera HTML. `WEB-INF` impide invocar directamente esas capas desde una URL pública.

Las sesiones HTTP se conservan en `grado.sesion_http` usando componentes nativos de Tomcat. El token de autenticación de negocio se valida además en PostgreSQL. Son mecanismos relacionados, pero diferentes: una cookie identifica la sesión HTTP y el token permite comprobar la identidad autorizada en las operaciones de negocio.

## 5. Estructura y archivos del proyecto

```text
Sistema Gestor de Proyectos de Grado/
├── src/main/webapp/
│   ├── index.jsp, ingresar.jsp, registro.jsp, panel.jsp ...
│   ├── acciones/                    Entradas públicas para operaciones POST
│   ├── assets/css/                  Diseño y estilos
│   ├── assets/img/                  Logo SVG e iconos locales
│   └── WEB-INF/
│       ├── web.xml                 Configuración y protección JSP/sesiones
│       ├── controladores/          Coordinación y permisos
│       ├── modelo/                 Consultas parametrizadas
│       └── vistas/                 Pantallas y componentes comunes
├── database/                       Esquema, catálogos, funciones y migraciones
│   ├── pruebas/                    Comprobaciones SQL específicas
│   └── supabase/                   Instalación y verificaciones de apoyo
├── docker/                         Arranque, JNDI, certificados y configuración
├── scripts/                        Pruebas y herramientas de preparación
├── docs/                           Decisiones, arquitectura y resultados
├── .mvn/                           Maven Wrapper
├── .tools/                         Datos locales privados, excluidos de Git
├── target/                         WAR y resultados de compilación
├── compose.yaml                    Ejecución conectada a la base configurada
├── compose.pruebas.yaml            Entorno PostgreSQL aislado
├── Dockerfile.vercel               Construcción Maven y ejecución Tomcat
├── pom.xml                         Dependencias y empaquetado WAR
├── mvnw / mvnw.cmd                 Lanzadores de Maven
├── .env.example                    Plantilla sin secretos
├── .gitignore / .dockerignore      Exclusiones de Git y de la imagen
└── README.md                       Entrada a la documentación existente
```

### Archivos representativos

| Archivo | Para qué sirve |
|---|---|
| `src/main/webapp/proyecto.jsp` | Entrada pública al detalle del proyecto. |
| `src/main/webapp/WEB-INF/controladores/proyecto.jsp` | Comprueba acceso y prepara el detalle. |
| `src/main/webapp/WEB-INF/vistas/proyecto.jsp` | Presenta seguimiento, fase y accesos del proyecto. |
| `src/main/webapp/WEB-INF/vistas/comun/fases-detalle.jsp` | Detalles desplegables de las fases iniciadas. |
| `src/main/webapp/WEB-INF/vistas/comun/docentes-resumen.jsp` | Nombres de director y evaluador en el resumen. |
| `src/main/webapp/WEB-INF/controladores/acciones/documentos-enviar.jsp` | Valida la presentación de documentos. |
| `src/main/webapp/WEB-INF/modelo/acciones/documentos-enviar/resultado.jsp` | Invoca la función SQL de presentación con parámetros. |
| `src/main/webapp/WEB-INF/vistas/documento.jsp` | Visor con iframe y enlace de apertura alternativo. |
| `docker/context.xml` | DataSource JDBC y persistencia nativa de sesiones. |
| `docker/iniciar.sh` | Comprueba `PORT` e inicia Tomcat en ese puerto. |
| `scripts/verificar_mvc.py` | Verifica la separación de capas y las entradas públicas. |
| `scripts/pruebas_completas.py` | Ejecuta la batería funcional en el entorno aislado. |

Los directorios `target`, `tmp`, `entrega` y `.tools` son resultados o apoyo local; no son rutas que deba visitar un usuario del sistema.

## 6. Recorrido de las peticiones

Diagrama de secuencia: [presentación y revisión en PNG](docs/diagramas/SECUENCIA_DOCUMENTOS.png) y [SVG ampliable](docs/diagramas/SECUENCIA_DOCUMENTOS.svg).

### Consulta de un proyecto

1. El navegador solicita `/proyecto.jsp?id=7` y envía su cookie de sesión.
2. La entrada incluye el controlador interno correspondiente.
3. Se prepara el contexto, se valida la sesión y se comprueba si el usuario puede consultar el proyecto.
4. El modelo consulta los datos mediante el pool JNDI `jdbc/Grado`, usando parámetros.
5. PostgreSQL devuelve proyecto, participantes, docentes, fases y datos autorizados.
6. La vista transforma esos resultados en HTML, escapando los textos del usuario.
7. Tomcat devuelve la respuesta y conserva los cambios de sesión cuando corresponda.

### Envío de documentos

1. El estudiante completa el formulario de seguimiento y pulsa **Enviar conjunto al director →**.
2. Se envía un `POST` a `/acciones/documentos-enviar.jsp` con proyecto, tipo de seguimiento, enlaces y token CSRF.
3. El controlador verifica método, sesión, rol estudiantil, CSRF y parámetros.
4. El modelo llama a `grado.presentar_documentos(...)` mediante `sql:param` y un objeto con los enlaces institucionales.
5. La función comprueba participación, estado, fase, plazos y documentos requeridos; registra las versiones y la entrega, abre la revisión del director y genera trazabilidad/avisos.
6. El resultado vuelve al controlador con éxito o explicación del rechazo.
7. El controlador redirige a `/seguimiento.jsp?id=...&tipo=propuesta` o `tipo=informe` y muestra el aviso.

Este patrón **POST → redirección → GET** evita repetir el formulario al recargar la página. Las validaciones de negocio también evitan abrir entregas incompatibles con el estado actual.

### Vencimientos sin usuarios conectados

Supabase Cron ejecuta el trabajo `grado-procesar-plazos` cada minuto e invoca `grado.procesar_plazos()`. La función procesa los vencimientos, actualiza los estados que corresponden y registra eventos y avisos. Por tanto, el cierre del navegador no detiene los plazos. El minuto de ejecución de la tarea y el momento en que el usuario vuelve a consultar pueden introducir una pequeña diferencia entre el vencimiento y su visualización.

## 7. Seguridad

| Control | Implementación y alcance |
|---|---|
| Contraseñas | Hash bcrypt mediante `pgcrypto`; no se guardan contraseñas en texto plano en `usuario`. Mínimo 8 caracteres y máximo 72 bytes UTF-8. |
| Registro | Estudiantes y docentes quedan activos automáticamente por decisión académica. No se comprueba propiedad del correo mediante un mensaje. |
| Intentos de acceso | Límite de intentos fallidos por identificador de correo y ventana temporal; no es un servicio externo de protección. |
| Token de acceso | Token aleatorio; en la base se conserva su hash SHA-256 y se valida vigencia y cuenta activa. |
| Sesión | Renovación de identificador al ingresar; cierre invalida sesión y revoca el acceso. Inactividad HTTP de 30 minutos y vigencia absoluta del token de negocio de 8 horas. |
| Cookies | `HttpOnly`, `SameSite=Lax` y `Secure` cuando la petición se reconoce como HTTPS detrás del proxy configurado. |
| Autorización | Validación en controladores y funciones SQL; ocultar un botón no es el único control. |
| CSRF | Las operaciones de escritura requieren `POST` y token de formulario válido; también se protegen ingreso y registro. |
| Inyección SQL | Valores enviados mediante parámetros, sin concatenar entradas del usuario en las consultas. |
| Salida HTML | Textos escapados con `c:out`; cabeceras de seguridad y control de caché. |
| Capas internas | Rutas de `WEB-INF` no accesibles directamente por HTTP. |
| Documentos externos | Se aceptan URLs HTTP/HTTPS; no esquemas ejecutables como `javascript:`. No se certifica el contenido del proveedor externo. |
| Credenciales de infraestructura | Variables externas al código; `.env` y `.tools` excluidos de Git y del contexto Docker. |
| Trazabilidad | Eventos, actores, versiones y decisiones conservados para consulta autorizada. |

La autenticación es propia del esquema `grado`; **no utiliza Supabase Auth**. Algunas funciones de negocio usan `SECURITY DEFINER`, rutas de búsqueda explícitas y restricciones de ejecución. La configuración de aula no debe presentarse como una arquitectura con una cuenta de aplicación de privilegio mínimo ya desplegada.

Los archivos DEMO alojados en un bucket público pueden ser abiertos por cualquiera que tenga su URL. El permiso para abrir la pantalla del documento no convierte ese archivo público en privado. No cargar información sensible en esos ejemplos.

La persistencia HTTP se comprobó entre dos instancias y después de un reinicio. No incorpora un bloqueo distribuido entre todas las JVM para escrituras simultáneas de una misma sesión; ese escenario sigue siendo una limitación.

## 8. Módulos y permisos

| Módulo / operación | Estudiante | Director | Evaluador | Comité | Secretaría |
|---|---|---|---|---|---|
| Inicio, cuenta y avisos | Propios | Propios | Propios | Propios | Propios |
| Banco de ideas | Consultar/proponer/elegir | Consultar/proponer | Consultar | Consultar/decidir | Consultar |
| Proyectos | Los vinculados | Los asignados | Los asignados | Consulta administrativa | Consulta administrativa |
| Pago | Presentar conjunto | Consulta si corresponde | Consulta si corresponde | Aprobar y asignar | Consulta |
| Propuesta e informe | Presentar y corregir | Primera revisión | Revisión posterior | Decisión final de la cadena | Consulta |
| Final | Manual, evidencia y licencia opcionales | Registrar repositorio | Consulta | Aprobar cierre | Consulta |
| Solicitudes | Crear y consultar las propias del proyecto | Consulta autorizada | Consulta autorizada | Decidir y aplicar | Consulta administrativa autorizada |
| Actas | Consultar las aprobadas vinculadas | Consultar aprobadas vinculadas | Consultar aprobadas vinculadas | Crear, consultar borradores y aprobar | Consultar aprobadas autorizadas |
| Mensajería | Con su director asignado | Con los estudiantes asignados | Sin acceso al intercambio privado | Sin acceso al intercambio privado | Sin acceso al intercambio privado |
| Pausa/reanudación | Consulta | Consulta | Consulta | Ejecutar | Consulta |
| Administrar cuentas | No | No | No | Sí | No |

Las consultas están sujetas a la relación con el proyecto y al estado de la cuenta. Una asignación histórica no equivale a permiso para ejecutar revisiones actuales. La bandeja **Mis tareas** concentra el trabajo pendiente que corresponde al usuario.

### Recorrido específico de Secretaría

Secretaría ingresa y utiliza **Mi inicio → Proyectos → Resumen / seguimiento**. Puede buscar proyectos, consultar participantes, director, evaluador, fase, documentos e historial administrativo autorizado. Puede consultar el banco y sus avisos. No aprueba pagos, documentos, cambios, retiros ni cierres; tampoco administra cuentas ni lee mensajes privados estudiante-director. La ausencia de esos formularios se complementa con rechazo de las acciones no autorizadas.

## 9. Usuarios y proyectos de prueba

### Acceso

Despliegue: [abrir sistema](https://sistema-gestor-de-proyectos-de-grad.vercel.app/).

Las cuentas ficticias utilizan `@grado.example`. Sus contraseñas individuales están en el archivo local privado [CREDENCIALES.md](.tools/demostracion/CREDENCIALES.md), excluido de Git. Este documento puede compartirse sin copiar esas contraseñas. Para entregar acceso al profesor, compartir el archivo privado por separado.

Antes de cada cambio de usuario del guion, pulsar **Cerrar sesión** e ingresar con la siguiente cuenta. Varias pestañas del mismo navegador comparten sesión: no sirven para mantener distintos roles independientes. Como alternativa, utilizar perfiles de navegador separados.

### Casos preparados

| ID | Proyecto DEMO | Estado preparado | Estudiante principal | Director / evaluador |
|---|---|---|---|---|
| 5 | EcoRuta | Pago pendiente del Comité | `demo.est.eco@grado.example` | Carlos / Jorge, previstos; aún sin asignar |
| 6 | AulaAccesible | Propuesta I corregida y reenviada al director | `demo.est.aula@grado.example` | Laura / Marcela |
| 7 | Observatorio | Propuesta II, Comité pendiente | `demo.est.observatorio@grado.example` | Laura / Marcela |
| 8 | BiblioLab | Informe I, director pendiente | `demo.est.biblio@grado.example` | Carlos / Jorge |
| 9 | AgroDatos | Informe II, evaluador pendiente | `demo.est.agro@grado.example` | Laura / Marcela |
| 10 | Sistema Gestor de Proyectos de Grado | Final, listo para cierre | `demo.est.gestor@grado.example` | Laura / Marcela |
| 11 | Gardenia | Finalizado | `demo.est.gardenia@grado.example` | Carlos / Jorge |
| 12 | RutaVerde | Pausado en Propuesta I | `demo.est.ruta@grado.example` | Carlos / Jorge |
| 13 | Panel de tutorías, del banco | Pago pendiente | `demo.est.nicolas@grado.example` | Natalia / Andrea, previstos; aún sin asignar |
| 14 | Consumo responsable, del banco | Propuesta I corregida | `demo.est.felipe@grado.example` | Natalia / Andrea |
| 15 | Inventario de laboratorio, del banco | Propuesta II, Comité pendiente | `demo.est.juliana@grado.example` | Natalia / Andrea |
| 16 | Hábitos de riego, del banco | Informe I, director pendiente | `demo.est.sebastian@grado.example` | Natalia / Andrea |
| 17 | Accesibilidad de formularios, del banco | Informe II, evaluador pendiente | `demo.est.manuel@grado.example` | Ricardo / Miguel |
| 18 | HuertaConecta, del banco | Pausado en Propuesta I | `demo.est.veronica@grado.example` | Ricardo / Miguel |

Ruta directa de cada caso: `/proyecto.jsp?id=ID`. Ejemplo: [proyecto 7](https://sistema-gestor-de-proyectos-de-grad.vercel.app/proyecto.jsp?id=7). Se necesita iniciar sesión con una cuenta autorizada.

Gestor, Gardenia, Panel de tutorías y Hábitos de riego tienen dos participantes. Ana y David están preparados sin proyecto para demostrar una selección nueva del banco. Hay ocho ideas docentes aprobadas disponibles en las cuatro modalidades en el conjunto preparado; una demostración posterior puede haber reservado alguna.

Los casos de Informe y Final contienen fechas históricas simuladas para superar los 90 días. No se alteró la regla global. Los formatos institucionales y las imágenes de similitud son **placeholders**, no evaluaciones reales ni comprobantes de un pago real.

### Inventario de cuentas

| Rol | Correo de prueba |
|---|---|
| comite | `demo.comite@grado.example` |
| secretaria | `demo.secretaria@grado.example` |
| director | `demo.director.laura@grado.example` |
| director | `demo.director.carlos@grado.example` |
| evaluador | `demo.evaluador.marcela@grado.example` |
| evaluador | `demo.evaluador.jorge@grado.example` |
| estudiante | `demo.est.eco@grado.example` |
| estudiante | `demo.est.aula@grado.example` |
| estudiante | `demo.est.observatorio@grado.example` |
| estudiante | `demo.est.biblio@grado.example` |
| estudiante | `demo.est.agro@grado.example` |
| estudiante | `demo.est.gestor@grado.example` |
| estudiante | `demo.est.gestor.pareja@grado.example` |
| estudiante | `demo.est.gardenia@grado.example` |
| estudiante | `demo.est.gardenia.pareja@grado.example` |
| estudiante | `demo.est.ruta@grado.example` |
| director | `demo.director.natalia@grado.example` |
| director | `demo.director.ricardo@grado.example` |
| evaluador | `demo.evaluador.andrea@grado.example` |
| evaluador | `demo.evaluador.miguel@grado.example` |
| estudiante | `demo.est.nicolas@grado.example` |
| estudiante | `demo.est.daniela@grado.example` |
| estudiante | `demo.est.felipe@grado.example` |
| estudiante | `demo.est.juliana@grado.example` |
| estudiante | `demo.est.sebastian@grado.example` |
| estudiante | `demo.est.antonella@grado.example` |
| estudiante | `demo.est.manuel@grado.example` |
| estudiante | `demo.est.veronica@grado.example` |
| estudiante | `demo.est.libre.ana@grado.example` |
| estudiante | `demo.est.libre.david@grado.example` |

### Enlaces preparados para los formularios

Copiar la dirección del enlace correspondiente en los campos del sistema. Los documentos se registran por URL; el formulario no sube archivos desde el equipo.

| Documento | URL para copiar |
|---|---|
| F-DC-124 | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/f_dc_124.doc |
| F-DC-125 | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/f_dc_125.docx |
| F-DC-129 | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/f_dc_129.docx |
| Turnitin Gardenia | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/turnitin_gardenia.png |
| Turnitin Gestor | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/turnitin_gestor.png |
| Comprobante DEMO | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/comprobante.txt |
| Adicional DEMO | https://kgrwqhoikgxoevheyhmm.supabase.co/storage/v1/object/public/grado-demostracion/demo-c6d2115abd007e299d3d/adicional.txt |

Repositorios disponibles como ejemplo:

- [Gardenia](https://github.com/JersonBee/Gardenia).
- [Sistema Gestor de Proyectos de Grado](https://github.com/JersonBee/Sistema-Gestor-de-Proyectos-de-Grado).

El visor ofrece **Previsualizar** y **Abrir enlace ↗**. Imágenes y texto son compatibles con el navegador; DOC/DOCX pueden descargarse o no mostrarse dentro del iframe. No existe un conversor a PDF o visor de Word incorporado. Que la URL funcione no garantiza su previsualización.

## 10. Guion de demostración por roles

### Preparación

Abrir [el sistema](https://sistema-gestor-de-proyectos-de-grad.vercel.app/) y tener a mano el archivo privado [CREDENCIALES.md](.tools/demostracion/CREDENCIALES.md). Al cambiar de usuario, pulsar **Cerrar sesión** e ingresar con la cuenta indicada. Las pestañas del mismo navegador comparten sesión.

Este recorrido utiliza los proyectos DEMO preparados para mostrar las distintas fases sin esperar 90 días. **Los pasos de aprobación, corrección, respuesta y cierre modifican los datos.** Antes de empezar, comprobar que los proyectos conservan las condiciones indicadas; si ya avanzaron, no repetir una aprobación ni interpretar la ausencia de su formulario como un error.

Condiciones iniciales: proyecto 5 en Pago pendiente; proyecto 6 con propuesta corregida pendiente de Laura; proyecto 7 con propuesta pendiente del Comité; proyecto 9 con informe pendiente de Marcela; proyecto 10 activo en Final. Los enlaces de los formatos están en la sección 9.

**Presentación:** “Voy a mostrar el recorrido de un trabajo de grado y qué puede hacer cada rol: el estudiante presenta, los docentes revisan, el Comité decide y Secretaría consulta”.

### Recorrido de 20 pasos

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| 1 | Sin sesión | Abrir el aplicativo y entrar al formulario de Registro; después regresar a Ingresar. | El acceso inicial muestra el login y permite acceder al registro. Las cuentas estudiantiles y docentes se activan automáticamente al completar un registro válido. Este paso solo consulta el formulario. |
| 2 | `demo.secretaria@grado.example` | Iniciar sesión y abrir **Proyectos**; buscar “Observatorio” y abrir el proyecto 7. | Se muestra el inicio de Secretaría y puede consultar el proyecto sin formularios de aprobación. |
| 3 | `demo.secretaria@grado.example` | Abrir `/resumen.jsp?id=7`; volver al seguimiento y pulsar una fase iniciada. | El resumen muestra a Laura como directora y Marcela como evaluadora. La fase actual o anterior iniciada abre sus detalles emergentes. |
| 4 | `demo.secretaria@grado.example` | Escribir `/usuarios.jsp` en la barra de dirección. | Se deniega la administración de cuentas; Secretaría conserva un rol de consulta administrativa. |
| 5 | `demo.est.eco@grado.example` | Cambiar de cuenta, abrir **Banco de ideas** y consultar la idea vinculada a EcoRuta; después abrir `/pago.jsp?id=5`. | La idea está reservada y el proyecto tiene un conjunto de Pago pendiente. Se ven participantes y comprobante, sin docentes formalmente asignados todavía. |
| 6 | `demo.comite@grado.example` | Abrir Pago del proyecto 5, revisar los enlaces, elegir **Aprobar conjunto**, escribir el reporte y guardar. | Queda aprobado el conjunto y se habilita la asignación de docentes. La aprobación no se registra archivo por archivo. |
| 7 | `demo.comite@grado.example` | En el proyecto 5 seleccionar Carlos como director y Jorge como evaluador; pulsar **Asignar y comenzar Propuesta I →**. | Se asignan docentes distintos que coinciden en modalidad, área y línea. El proyecto avanza a Propuesta I. |
| 8 | `demo.est.eco@grado.example` | Abrir `/seguimiento.jsp?id=5&tipo=propuesta`; pegar los enlaces F-DC-124 y Turnitin Gestor de la sección 9 y pulsar **Enviar conjunto al director →**. | Se registra la entrega y queda una revisión pendiente de Carlos. Los adicionales son opcionales. |
| 9 | `demo.director.carlos@grado.example` | Abrir la tarea de propuesta del proyecto 5; elegir **Solicitar correcciones**, escribir “Precisar el alcance de la propuesta” y guardar. | El conjunto vuelve al estudiante con un reporte y plazo de corrección. No avanza al evaluador. |
| 10 | `demo.est.eco@grado.example` | Consultar **Mis avisos** y la propuesta del proyecto 5; leer el reporte y reenviar todos los enlaces del conjunto. | Se conserva la entrega anterior y se registra otra con sus versiones. La revisión vuelve a Carlos. Explicar que vencer los tres días genera una alerta, pero no bloquea el reenvío. |
| 11 | `demo.director.laura@grado.example` | Abrir la propuesta del proyecto 6, AulaAccesible, que ya tiene una corrección reenviada; aprobar el conjunto con reporte. | El proyecto 6 pasa a Propuesta II y queda pendiente de Marcela. Se utiliza otro caso preparado para mostrar la continuidad de la cadena. |
| 12 | `demo.evaluador.marcela@grado.example` | Abrir la revisión de propuesta del proyecto 6; aprobar y registrar reporte. | El conjunto pasa al Comité. La aprobación del evaluador todavía no inicia Informe I. |
| 13 | `demo.comite@grado.example` | Abrir la revisión pendiente de propuesta del proyecto 7, Observatorio; aprobar el conjunto con reporte. | El proyecto 7 inicia Informe I. Se conservan las decisiones anteriores. Se usa el caso 7 para mantener separados los ejemplos preparados. |
| 14 | `demo.est.observatorio@grado.example` | Abrir `/seguimiento.jsp?id=7&tipo=informe` y consultar el historial. | Se muestra la espera de 90 días desde el inicio de Informe I y no se permite presentar inmediatamente el informe. El historial conserva el avance anterior. |
| 15 | `demo.evaluador.marcela@grado.example` | Abrir `/seguimiento.jsp?id=9&tipo=informe`, AgroDatos. Consultar F-DC-125, F-DC-129 y Turnitin; aprobar la revisión con reporte. | Se ofrece previsualización y enlace alternativo. Word puede requerir descarga. El informe, ya aprobado por el director en este caso histórico, pasa al Comité. |
| 16 | `demo.comite@grado.example` | Abrir la revisión pendiente de informe del proyecto 9 y aprobar el conjunto con reporte. | AgroDatos avanza a Final sin exigir documentos adicionales opcionales. El caso contiene fechas históricas de demostración que respetan la espera académica. |
| 17 | `demo.est.gestor@grado.example` | En el proyecto 10, abrir Mensajes y enviar una consulta a Laura; después crear una **Solicitud general** en `/solicitudes.jsp?id=10`. | El mensaje queda en el canal privado con la directora. La solicitud queda pendiente de decisión del Comité; enviar una solicitud no aplica un cambio automáticamente. |
| 18 | `demo.director.laura@grado.example` | Abrir los mensajes del proyecto 10 y responder; después abrir `/final.jsp?id=10` y guardar el repositorio del Sistema Gestor indicado en la sección 9. | La respuesta queda visible para el estudiante destinatario y se registra el repositorio a nombre de la directora. El campo de repositorio corresponde al director. |
| 19 | `demo.comite@grado.example` | En el proyecto 10, responder la solicitud del paso 17 como **atendida**; luego abrir Final y pulsar **Aprobar cierre y finalizar proyecto** con una observación. | La solicitud conserva la respuesta. El proyecto queda finalizado, se cierran participaciones y asignaciones vigentes y se conserva la idea y el historial. |
| 20 | `demo.est.gestor@grado.example` | Volver a ingresar; consultar la respuesta a su solicitud, el mensaje de Laura, el estado final y el historial del proyecto 10. | Se conservan las comunicaciones autorizadas y el resultado del trámite. El proyecto finalizado permite consulta y no habilita procedimientos académicos de un proyecto activo. |

### Qué explicar al terminar

“El recorrido utiliza varios proyectos preparados para mostrar las fases sin alterar sus plazos. Las restricciones evitan duplicar reservas, participantes y asignaciones vigentes. Cada entrega conserva sus versiones y cada decisión queda asociada al responsable”.

Este guion resume las comprobaciones principales; no sustituye las pruebas de pausas, retiros, cambios de docente, actas, administración de cuentas y vencimientos automáticos descritas en la documentación técnica y los informes de pruebas. No se deben modificar las fechas de Supabase para acelerar la exposición. No hay un reinicio automático de los casos DEMO después de ejecutar estas acciones.

## 11. Verificación técnica y límites

La revisión del 19 de octubre registra una suite local integral satisfactoria, 729 comprobaciones adicionales en la matriz de roles, 51 rutas públicas verificadas para MVC y 71 comprobaciones HTTP del despliegue. El número 729 corresponde a esa matriz, no al total de aserciones de toda la suite.

Se comprobaron registro, acceso, CSRF, reserva, asignación, revisiones, correcciones, tiempos, pausas, cierre, solicitudes, actas, mensajes, paginación y persistencia de sesión. Las escrituras de la revisión integral se realizaron en PostgreSQL aislado, no como cambios académicos sobre Supabase.

Para repetir las verificaciones técnicas, desde la raíz y con Docker disponible:

```powershell
python scripts/verificar_mvc.py
python -u scripts/pruebas_completas.py
```

La suite integral prepara datos y reinicia el esquema del entorno **de pruebas**. Revisar su configuración antes de ejecutarla; no apuntarla a la base del despliegue ni copiar procedimientos de limpieza a Supabase.

Los resultados detallados están en [Revisión funcional del 19 de octubre](docs/REVISION_FUNCIONAL_2026-10-19.md). Allí se distinguen comprobaciones HTTP, integridad de archivos e inspección visual. No se confirmó visualmente todo el despliegue ni se obtuvo acceso a sus logs actuales por MCP durante aquella revisión; el acceso MCP a Vercel respondió 403.

Esta documentación no certifica ausencia de cualquier defecto ni carga masiva. El guion registra lo que **debe ocurrir** y ofrece una columna para contrastarlo con la ejecución. Si un caso ya cambió de fase, adaptar el recorrido a su estado real antes de interpretar la ausencia de un botón como un error.

## 12. Diccionario de datos

Fuente: definición SQL del repositorio, incluyendo las modificaciones aditivas de las migraciones 008 y 013. Describe el esquema previsto por estos archivos; no se realizó una extracción en vivo de Supabase para elaborar este anexo.

**Convenciones:** PK = clave primaria; FK = clave foránea; Sí = columna no admite NULL. “Obligatorio” se refiere a la base de datos, no a que el usuario deba escribirlo: identificadores y fechas pueden generarse automáticamente. Las reglas UNIQUE e índices parciales se detallan en la sección 3. `text` es texto de longitud variable; `timestamptz` es fecha/hora con zona; `jsonb` es JSON; `bytea` es contenido binario.

### `grado.rol`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `codigo` | `text` | Sí | PK | Código estable del catálogo. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |

### `grado.usuario`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `rol_codigo` | `text` | Sí | FK → `rol.codigo` | Único rol de la cuenta; referencia al catálogo de roles. |
| `nombre` | `text` | Sí | — | Nombre de la persona o elemento del catálogo. |
| `numero_documento` | `text` | No | — | Documento de identidad informado por el usuario. |
| `telefono` | `text` | No | — | Teléfono de contacto. |
| `correo` | `text` | Sí | — | Correo utilizado como identificador de acceso. |
| `contrasena_hash` | `text` | Sí | — | Hash bcrypt; no contiene la contraseña original. |
| `estado` | `text` | Sí | — | Estado del registro; consultar el catálogo de estados al final del diccionario. Por defecto: `'pendiente'`. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |
| `actualizado_en` | `timestamptz` | Sí | — | Fecha de última modificación; actualizada por trigger en usuario y proyecto. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.area_experiencia`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |

### `grado.perfil_docente`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `usuario_id` | `bigint` | Sí | PK, FK → `usuario.id` | Cuenta de usuario vinculada. |
| `cursos` | `text` | Sí | — | Cursos o asignaturas del perfil docente. |
| `titulos_academicos` | `text` | Sí | — | Formación académica declarada. |
| `temas_preferencia` | `text` | Sí | — | Temas de interés docente. |

### `grado.docente_area`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `docente_id` | `bigint` | Sí | PK, FK → `perfil_docente.usuario_id` | Docente vinculado mediante su perfil. |
| `area_id` | `bigint` | Sí | PK, FK → `area_experiencia.id` | Área de experiencia asociada. |

### `grado.modalidad`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `codigo` | `text` | Sí | UNIQUE | Código estable del catálogo. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |

### `grado.docente_modalidad`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `docente_id` | `bigint` | Sí | PK, FK → `perfil_docente.usuario_id` | Docente vinculado mediante su perfil. |
| `modalidad_id` | `bigint` | Sí | PK, FK → `modalidad.id` | Modalidad de trabajo de grado. |

### `grado.linea_investigacion`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |

### `grado.docente_linea`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `docente_id` | `bigint` | Sí | PK, FK → `perfil_docente.usuario_id` | Docente vinculado mediante su perfil. |
| `linea_id` | `bigint` | Sí | PK, FK → `linea_investigacion.id` | Línea de investigación asociada. |

### `grado.idea`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `autor_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta que propuso la idea. |
| `modalidad_id` | `bigint` | Sí | FK → `modalidad.id` | Modalidad de trabajo de grado. |
| `area_id` | `bigint` | Sí | FK → `area_experiencia.id` | Área de experiencia asociada. |
| `linea_id` | `bigint` | Sí | FK → `linea_investigacion.id` | Línea de investigación asociada. |
| `titulo` | `text` | Sí | — | Título descriptivo de la idea o proyecto. |
| `descripcion` | `text` | Sí | — | Descripción del registro o motivo detallado del trámite. |
| `objetivos` | `text` | Sí | — | Objetivos académicos propuestos. |
| `tecnologias` | `text` | Sí | — | Tecnologías declaradas para la idea. |
| `estado` | `text` | Sí | — | Estado del registro; consultar el catálogo de estados al final del diccionario. Por defecto: `'pendiente'`. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.decision_idea`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `idea_id` | `bigint` | Sí | FK → `idea.id` | Idea asociada; su reserva depende del estado del proyecto. |
| `responsable_id` | `bigint` | Sí | FK → `usuario.id` | Usuario responsable de la decisión o respuesta. |
| `decision` | `text` | Sí | — | Resultado de la revisión; NULL significa pendiente cuando la columna lo permite. |
| `observaciones` | `text` | No | — | Observaciones escritas por quien toma la decisión. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.proyecto`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `idea_id` | `bigint` | Sí | FK → `idea.id` | Idea asociada; su reserva depende del estado del proyecto. |
| `modalidad_id` | `bigint` | Sí | FK → `modalidad.id` | Modalidad de trabajo de grado. |
| `titulo` | `text` | Sí | — | Título descriptivo de la idea o proyecto. |
| `objetivos` | `text` | Sí | — | Objetivos académicos propuestos. |
| `descripcion` | `text` | Sí | — | Descripción del registro o motivo detallado del trámite. |
| `creado_por` | `bigint` | Sí | FK → `usuario.id` | Usuario creador del proyecto. |
| `estado` | `text` | Sí | — | Estado del registro; consultar el catálogo de estados al final del diccionario. Por defecto: `'activo'`. |
| `inicio_vigencia_en` | `timestamptz` | No | — | Inicio del reloj académico al comenzar Informe I. |
| `informe_habilitado_en` | `timestamptz` | No | — | Fecha efectiva a partir de la que se permite presentar el informe, tras 90 días y ajustes por pausa. |
| `vence_en` | `timestamptz` | No | — | Vencimiento del token o límite académico, según la tabla. |
| `informe_aprobado_comite_en` | `timestamptz` | No | — | Aprobación del informe por Comité; detiene la cancelación por plazo. |
| `finalizado_por` | `bigint` | No | FK → `usuario.id` | Comité que formalizó la finalización. |
| `finalizado_en` | `timestamptz` | No | — | Fecha de cierre del proyecto o ciclo. |
| `motivo_desactivacion` | `text` | No | — | Motivo registrado al pausar el proyecto. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |
| `actualizado_en` | `timestamptz` | Sí | — | Fecha de última modificación; actualizada por trigger en usuario y proyecto. Por defecto: `CURRENT_TIMESTAMP`. |
| `aviso_informe_habilitado_en` | `timestamptz` | No | — | Momento de emisión del aviso que habilita la presentación de informe. Añadido en 008. |

### `grado.pausa_proyecto`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `pausado_por` | `bigint` | Sí | FK → `usuario.id` | Usuario del Comité que inició la pausa. |
| `inicio_en` | `timestamptz` | Sí | — | Inicio del período registrado. Por defecto: `CURRENT_TIMESTAMP`. |
| `motivo` | `text` | Sí | — | Justificación de la pausa. |
| `reanudado_por` | `bigint` | No | FK → `usuario.id` | Usuario que reanudó el proyecto. |
| `fin_en` | `timestamptz` | No | — | Fin del período; NULL identifica una pausa o asignación abierta. |

### `grado.participante_proyecto`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `estudiante_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta estudiantil participante. |
| `nombre_en_pago` | `text` | Sí | — | Nombre presentado en Pago; conserva la instantánea de ese trámite. |
| `documento_en_pago` | `text` | No | — | Documento presentado en Pago. |
| `correo_en_pago` | `text` | Sí | — | Correo presentado en Pago. |
| `telefono_en_pago` | `text` | No | — | Teléfono presentado en Pago. |
| `plaza` | `smallint` | Sí | — | Lugar del participante: 1 o 2. |
| `ingreso_en` | `timestamptz` | Sí | — | Fecha de inicio de la participación. Por defecto: `CURRENT_TIMESTAMP`. |
| `retiro_en` | `timestamptz` | No | — | Fin de la participación vigente; NULL mientras continúe abierta. |

### `grado.asignacion_proyecto`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `docente_id` | `bigint` | Sí | FK → `perfil_docente.usuario_id` | Docente vinculado mediante su perfil. |
| `funcion` | `text` | Sí | — | Función asignada: director o evaluador. |
| `asignado_por` | `bigint` | Sí | FK → `usuario.id` | Comité que registró la asignación. |
| `inicio_en` | `timestamptz` | Sí | — | Inicio del período registrado. Por defecto: `CURRENT_TIMESTAMP`. |
| `fin_en` | `timestamptz` | No | — | Fin del período; NULL identifica una pausa o asignación abierta. |

### `grado.fase`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `codigo` | `text` | Sí | PK | Código estable del catálogo. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |
| `orden` | `smallint` | Sí | UNIQUE | Posición positiva y única de la fase. |

### `grado.proyecto_fase`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `fase_codigo` | `text` | Sí | FK → `fase.codigo` | Fase del catálogo correspondiente. |
| `estado` | `text` | No | — | Resultado de la fase; NULL indica que todavía no existe resultado. |
| `iniciada_en` | `timestamptz` | No | — | Inicio de la fase; NULL si no ha comenzado. |
| `finalizada_en` | `timestamptz` | No | — | Finalización de la fase; NULL si aún no se cierra. |

### `grado.tipo_documento`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `codigo` | `text` | Sí | PK | Código estable del catálogo. |
| `nombre` | `text` | Sí | UNIQUE | Nombre de la persona o elemento del catálogo. |

### `grado.documento`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `proyecto_fase_id` | `bigint` | Sí | — | Fase concreta del proyecto que contiene el documento. |
| `tipo_codigo` | `text` | Sí | FK → `tipo_documento.codigo` | Tipo documental institucional o adicional. |
| `etiqueta` | `text` | Sí | — | Identificador descriptivo del documento; requerido para adicionales. Por defecto: `''`. |

FK compuesta: `(proyecto_fase_id, proyecto_id)` → `proyecto_fase(id, proyecto_id)`.

### `grado.documento_version`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `documento_id` | `bigint` | Sí | FK → `documento.id` | Documento lógico al que pertenece la versión o vínculo. |
| `numero` | `integer` | Sí | — | Consecutivo de versión/entrega/ciclo o número institucional del acta, según la tabla. |
| `url` | `text` | Sí | — | Enlace HTTP/HTTPS de la versión; no contiene el archivo binario. |
| `registrado_por` | `bigint` | Sí | FK → `usuario.id` | Usuario que registró la versión. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.entrega_revision`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `fase_origen_id` | `bigint` | Sí | — | Fase en que se presentó el conjunto; se relaciona también mediante proyecto_id. |
| `numero` | `integer` | Sí | — | Consecutivo de versión/entrega/ciclo o número institucional del acta, según la tabla. |
| `presentada_por` | `bigint` | Sí | FK → `usuario.id` | Estudiante que presentó el conjunto. |
| `presentada_en` | `timestamptz` | Sí | — | Momento de presentación del conjunto. Por defecto: `CURRENT_TIMESTAMP`. |

FK compuesta: `(fase_origen_id, proyecto_id)` → `proyecto_fase(id, proyecto_id)`.

### `grado.entrega_documento_version`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `entrega_id` | `bigint` | Sí | PK | Entrega cuyos documentos o ciclos se registran. |
| `proyecto_id` | `bigint` | Sí | — | Proyecto al que pertenece el registro. |
| `documento_id` | `bigint` | Sí | PK | Documento lógico al que pertenece la versión o vínculo. |
| `version_id` | `bigint` | Sí | — | Versión exacta sometida a revisión. |

FK compuestas: `(entrega_id, proyecto_id)` → `entrega_revision`; `(documento_id, proyecto_id)` → `documento`; `(version_id, documento_id)` → `documento_version`.

### `grado.ciclo_revision`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `entrega_id` | `bigint` | Sí | FK → `entrega_revision.id` | Entrega cuyos documentos o ciclos se registran. |
| `numero` | `integer` | Sí | — | Consecutivo de versión/entrega/ciclo o número institucional del acta, según la tabla. |
| `iniciado_en` | `timestamptz` | Sí | — | Inicio del ciclo de revisión. Por defecto: `CURRENT_TIMESTAMP`. |
| `finalizado_en` | `timestamptz` | No | — | Fecha de cierre del proyecto o ciclo. |

### `grado.revision_entrega`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `ciclo_id` | `bigint` | Sí | FK → `ciclo_revision.id` | Ciclo de evaluación al que corresponde la etapa. |
| `etapa` | `text` | Sí | — | Responsable funcional: director, evaluador o Comité. |
| `responsable_id` | `bigint` | No | FK → `usuario.id` | Usuario responsable de la decisión o respuesta. |
| `asignada_en` | `timestamptz` | Sí | — | Inicio de la revisión asignada. Por defecto: `CURRENT_TIMESTAMP`. |
| `limite_en` | `timestamptz` | No | — | Fecha límite efectiva de revisión o corrección. |
| `decision` | `text` | No | — | Resultado de la revisión; NULL significa pendiente cuando la columna lo permite. |
| `reporte_respuesta` | `text` | No | — | Texto explicativo de aprobación o corrección. |
| `decidida_en` | `timestamptz` | No | — | Momento en que se registró la decisión. |

### `grado.plazo_correccion`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `revision_id` | `bigint` | Sí | FK → `revision_entrega.id`, UNIQUE | Revisión que originó el plazo de corrección. |
| `inicio_en` | `timestamptz` | Sí | — | Inicio del período registrado. |
| `limite_en` | `timestamptz` | Sí | — | Fecha límite efectiva de revisión o corrección. |
| `entrega_reenvio_id` | `bigint` | No | FK → `entrega_revision.id`, UNIQUE | Nueva entrega que atiende la corrección; NULL si aún no se reenvió. |
| `alertada_en` | `timestamptz` | No | — | Momento en que se emitió la alerta de corrección vencida; evita avisos repetidos. Añadido en 008. |

### `grado.datos_pago`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `proyecto_id` | `bigint` | Sí | PK, FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `director_propuesto_id` | `bigint` | No | FK → `perfil_docente.usuario_id` | Preferencia docente del estudiante; no es una asignación formal. |
| `aprobado_por` | `bigint` | No | FK → `usuario.id` | Comité que aprobó el conjunto de Pago. |
| `aprobado_en` | `timestamptz` | No | — | Fecha de aprobación de Pago. |

### `grado.entrega_final`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `proyecto_id` | `bigint` | Sí | PK, FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `tipo_licencia` | `text` | No | — | Nombre de la licencia declarada, opcional. |
| `repositorio_url` | `text` | No | — | Enlace al repositorio registrado por el director. |
| `repositorio_registrado_por` | `bigint` | No | FK → `usuario.id` | Director que registró el repositorio. |
| `repositorio_registrado_en` | `timestamptz` | No | — | Fecha del registro del repositorio. |

### `grado.solicitud`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `solicitante_id` | `bigint` | Sí | FK → `usuario.id` | Estudiante que presenta la solicitud. |
| `tipo` | `text` | Sí | — | Clase de solicitud: general, cambio, retiro, queja o reclamo. |
| `descripcion` | `text` | Sí | — | Descripción del registro o motivo detallado del trámite. |
| `docente_preferido_id` | `bigint` | No | FK → `perfil_docente.usuario_id` | Docente propuesto para un cambio; obligatorio para solicitudes de cambio docente. |
| `estado` | `text` | Sí | — | Estado del registro; consultar el catálogo de estados al final del diccionario. Por defecto: `'pendiente'`. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.respuesta_solicitud`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `solicitud_id` | `bigint` | Sí | FK → `solicitud.id` | Solicitud respondida. |
| `responsable_id` | `bigint` | Sí | FK → `usuario.id` | Usuario responsable de la decisión o respuesta. |
| `estado_resultante` | `text` | Sí | — | Estado que queda después de responder. |
| `respuesta` | `text` | Sí | — | Respuesta escrita por el Comité. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.acta`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `numero` | `text` | Sí | UNIQUE | Número institucional del acta; es texto y no puede repetirse. |
| `fecha` | `date` | Sí | — | Fecha administrativa del acta. |
| `descripcion` | `text` | Sí | — | Descripción del registro o motivo detallado del trámite. |
| `detalles` | `text` | Sí | — | Contenido detallado del acta. |
| `creada_por` | `bigint` | Sí | FK → `usuario.id` | Comité que creó el acta. |
| `aprobada_por` | `bigint` | No | FK → `usuario.id` | Comité que aprobó el acta; NULL mientras sea borrador. |
| `aprobada_en` | `timestamptz` | No | — | Momento de aprobación del acta. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.acta_proyecto`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `acta_id` | `bigint` | Sí | PK, FK → `acta.id` | Acta vinculada al proyecto. |
| `proyecto_id` | `bigint` | Sí | PK, FK → `proyecto.id` | Proyecto al que pertenece el registro. |

### `grado.mensaje`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | Sí | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `remitente_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta que envió el mensaje. |
| `destinatario_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta receptora del mensaje o aviso. |
| `contenido` | `text` | Sí | — | Texto del mensaje privado. |
| `enviado_en` | `timestamptz` | Sí | — | Fecha de envío del mensaje. Por defecto: `CURRENT_TIMESTAMP`. |
| `leido_en` | `timestamptz` | No | — | Momento de lectura; NULL mientras no se marque como leído. |

### `grado.evento_auditoria`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `proyecto_id` | `bigint` | No | FK → `proyecto.id` | Proyecto al que pertenece el registro. |
| `actor_id` | `bigint` | No | FK → `usuario.id` | Cuenta que originó el evento; NULL cuando el origen es el sistema. |
| `origen` | `text` | Sí | — | Origen del evento: usuario o sistema. |
| `accion` | `text` | Sí | — | Código descriptivo de la operación registrada. |
| `entidad` | `text` | Sí | — | Nombre de la entidad afectada. |
| `entidad_id` | `bigint` | Sí | — | Identificador de la entidad afectada. |
| `datos_anteriores` | `jsonb` | No | — | Instantánea JSON anterior, cuando corresponda. |
| `datos_nuevos` | `jsonb` | No | — | Instantánea JSON posterior, cuando corresponda. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.notificacion`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `evento_id` | `bigint` | Sí | FK → `evento_auditoria.id` | Evento de auditoría que generó el aviso. |
| `destinatario_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta receptora del mensaje o aviso. |
| `asunto` | `text` | Sí | — | Título del aviso interno. |
| `cuerpo` | `text` | Sí | — | Contenido del aviso interno. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |
| `leido_en` | `timestamptz` | No | — | Momento de lectura; NULL mientras no se marque como leído. |

### `grado.sesion_acceso`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `token_hash` | `text` | Sí | PK | Hash SHA-256 del token de autenticación; no es el token original. |
| `usuario_id` | `bigint` | Sí | FK → `usuario.id` | Cuenta de usuario vinculada. |
| `creada_en` | `timestamptz` | Sí | — | Momento de creación de la sesión de acceso. Por defecto: `CURRENT_TIMESTAMP`. |
| `vence_en` | `timestamptz` | Sí | — | Expiración absoluta de la sesión de negocio; valor inicial: creación más ocho horas. Por defecto: `CURRENT_TIMESTAMP + interval '8 hours'`. |
| `revocada` | `boolean` | Sí | — | Indica si se invalidó el token antes de su vencimiento. Por defecto: `false`. |

### `grado.intento_acceso`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `bigint` | Sí | PK | Identificador de la fila. Autogenerado por identidad. |
| `correo_hash` | `text` | Sí | — | Huella del correo asociada al intento fallido; no almacena el correo como texto legible. |
| `creado_en` | `timestamptz` | Sí | — | Fecha de creación del registro. Por defecto: `CURRENT_TIMESTAMP`. |

### `grado.sesion_http`

| Campo | Tipo | Obligatorio | Clave / relación | Significado |
|---|---|---|---|---|
| `id` | `varchar(100)` | Sí | PK | Identificador de sesión HTTP utilizado por Tomcat. |
| `aplicacion` | `varchar(255)` | Sí | PK | Identificador de contexto usado por el almacén nativo de Tomcat. |
| `datos` | `bytea` | Sí | — | Sesión HTTP serializada por Tomcat; no son documentos académicos. |
| `valida` | `char(1)` | Sí | — | Indicador interno de validez de la sesión Tomcat. |
| `inactividad_maxima` | `integer` | Sí | — | Tiempo máximo de inactividad, expresado en segundos. |
| `ultimo_acceso` | `bigint` | Sí | — | Marca temporal interna de Tomcat en milisegundos desde la época Unix. |

### Estados y códigos que requieren interpretación

| Entidad / campo | Valores e interpretación |
|---|---|
| `usuario.estado` | `pendiente`, `activo`, `inactivo`. El registro público de estudiante/director/evaluador convierte pendiente en activo automáticamente. |
| `usuario.rol_codigo` | `estudiante`, `director`, `evaluador`, `comite`, `secretaria`; uno por cuenta. |
| `idea.estado` / `decision_idea.decision` | `pendiente` (solo estado de idea), `aprobada`, `rechazada`. |
| `proyecto.estado` | `activo`: tramitable; `desactivado`: pausado; `cancelado`: terminado sin culminar y libera idea; `finalizado`: cierre aprobado y conserva reserva. |
| `fase.codigo` | `pago`, `propuesta_1`, `propuesta_2`, `informe_1`, `informe_2`, `final`. |
| `proyecto_fase.estado` / `revision_entrega.decision` | `aprobado`, `rechazado`, `aplicado`; NULL significa sin resultado. `aplicado` es un resultado operativo, por ejemplo de procesamiento automático, no una aprobación académica. Consultar el evento/reporte asociado. |
| `solicitud.tipo` | `cambio_director`, `cambio_evaluador`, `retiro`, `reclamo`, `queja`, `solicitud`. |
| `solicitud.estado` / `respuesta_solicitud.estado_resultante` | `pendiente`, `aprobada`, `rechazada`, `atendida`; atender una consulta no equivale a aprobar un cambio. |
| `acta` | No tiene columna estado: aprobada cuando existen `aprobada_por` y `aprobada_en`; de lo contrario es borrador. |
| Reserva de idea | No es un campo de estado de idea: se determina por su vínculo con un proyecto no cancelado. |
| `docente_apto_idea` | Vista con `idea_id` y `docente_id`; devuelve docentes activos que coinciden simultáneamente en modalidad, área y línea. No asigna al docente. |


## 13. Recuperación de acceso

### Qué está implementado

El ingreso utiliza correo y contraseña. **No existe una pantalla de “Olvidé mi contraseña”, enlace de recuperación, envío de correo ni cambio de contraseña desde Mi cuenta o Administrar cuentas.** El panel del Comité permite modificar rol y estado, no restablecer contraseñas. Esta sección documenta el procedimiento operativo disponible; no incorpora una funcionalidad nueva.

| Situación | Procedimiento | Resultado esperado |
|---|---|---|
| Se olvidó la contraseña de una cuenta DEMO | Consultar el archivo privado `CREDENCIALES.md`, si la clave no fue cambiada posteriormente. | Se recupera la credencial guardada durante la preparación, no desde la base de datos. |
| El correo o contraseña son incorrectos | Revisar el correo completo, mayúsculas de la contraseña y espacios copiados. | Se puede ingresar con las credenciales correctas si la cuenta está activa y no opera el límite de intentos. |
| Se alcanzó el límite de intentos | Dejar de reintentar y esperar a que salgan de la ventana de 15 minutos los intentos fallidos que causaron el límite. | El bloqueo temporal deja de impedir un nuevo intento válido. No confundirlo con una cuenta inactiva. |
| La cuenta está inactiva | Otro usuario activo del Comité busca la cuenta en Administrar cuentas y cambia su estado a activo, conservando el rol apropiado. | El usuario puede iniciar una sesión nueva. Reactivar no cambia la contraseña ni restaura sesiones revocadas. |
| Expiró la sesión | Volver a Ingresar con las credenciales válidas. | Se crea una sesión nueva. No requiere cambiar la contraseña. |
| Se olvidó una contraseña que no está guardada | Solicitar un restablecimiento manual al responsable técnico con acceso autorizado a PostgreSQL. | Se conserva la cuenta y sus vínculos académicos, sustituyendo solo su hash y revocando tokens anteriores. |
| No puede ingresar ninguna cuenta del Comité | El responsable técnico debe comprobar el estado de las cuentas y recuperar una existente desde la base. | Se recupera administración sin eliminar usuarios, proyectos ni historial. `crear-comite.ps1` es para el arranque inicial, no para reiniciar la contraseña de una cuenta existente. |
| Falla la conexión a la base o aparece “No pudimos conectar” | Revisar estado del servicio, variables de conexión y logs del contenedor/despliegue. | Se resuelve una incidencia de infraestructura; no se deben cambiar contraseñas de usuarios para intentar corregirla. |

### Restablecimiento manual por el responsable técnico

1. Verificar por un medio conocido la identidad de la persona y confirmar la cuenta exacta mediante su correo e ID. No crear otra cuenta con correo diferente para sustituirla: perdería la relación con sus participaciones y asignaciones.
2. Acceder a PostgreSQL mediante una herramienta administrativa autorizada. La operación se realiza fuera de las pantallas normales de la aplicación.
3. Generar una contraseña nueva de al menos 8 caracteres y como máximo 72 bytes UTF-8. Guardar en `usuario.contrasena_hash` el resultado de `grado.crear_hash_contrasena(...)`, nunca la contraseña en texto plano. Ejecutar la operación con parámetros o entrada protegida, evitando dejar la clave en scripts, historial del terminal o consultas guardadas.
4. En la misma transacción, marcar como revocados los registros de `grado.sesion_acceso` correspondientes al `usuario_id`. No hace falta borrar indiscriminadamente todas las sesiones HTTP: el token revocado se rechaza al validar el acceso.
5. Conservar el ID, rol, estado y vínculos académicos de la cuenta. Si además estaba inactiva, decidir y documentar por separado si corresponde reactivarla; cambiar una contraseña no debe hacerlo de forma implícita.
6. Registrar el motivo, fecha, cuenta y responsable de la intervención en la bitácora de mantenimiento. Una actualización SQL directa no genera por sí sola el evento de las funciones de administración: no atribuirle auditoría automática. No registrar contraseñas, hashes ni tokens en esa bitácora.
7. Entregar la nueva contraseña por un canal privado y comprobar un ingreso nuevo. Para cuentas DEMO, actualizar también el archivo privado de credenciales.

**Límite actual:** el sistema no exige cambiar una contraseña temporal al ingresar y no ofrece un formulario para hacerlo. Por ello, el responsable debe entregar una clave nueva adecuada para su uso, no prometer un cambio posterior desde una pantalla inexistente. No es posible obtener la contraseña original a partir del hash almacenado.

## 14. Casos alternos del guion

Estos casos son **opcionales e independientes del guion principal de 20 pasos**. Utilizan la misma estructura: usuario, acción y resultado esperado. Ejecutarlos después del recorrido principal, o reservar proyectos distintos, para no cambiar sus condiciones iniciales. Salvo las consultas y rechazos, modifican datos DEMO y no se reinician automáticamente.

### A. Pausa y reanudación

Condición: RutaVerde, proyecto 12, continúa pausado y conserva sus asignaciones.

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| A1 | `demo.est.ruta@grado.example` | Abrir `/proyecto.jsp?id=12` y su seguimiento. | Se identifica la pausa y no se habilitan los trámites académicos ordinarios. |
| A2 | `demo.comite@grado.example` | Abrir el proyecto 12 y pulsar **Reanudar proyecto**. | Pasa a activo; se cierra la pausa y se ajustan los plazos pendientes. Cada día o fracción de pausa se repone como día calendario, conservando la hora de cierre. |
| A3 | `demo.est.ruta@grado.example` | Consultar otra vez el proyecto y su historial. | Se conserva la pausa anterior, su fin y el procedimiento pendiente. |
| A4 | `demo.comite@grado.example` | Si se desea volver a dejarlo pausado, escribir “Pausa de demostración” y pulsar **Pausar proyecto**. | Se abre una pausa nueva. No se borra ni se deshace la reanudación registrada anteriormente. |

### B. Cambio de director o evaluador

Condición: proyecto 14 activo; Felipe es participante y Natalia/Andrea conservan sus asignaciones. Usar docentes aptos distintos de los actuales. Los nombres deben aparecer en el selector; no forzar un ID ajeno al listado.

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| B1 | `demo.est.felipe@grado.example` | En `/solicitudes.jsp?id=14`, seleccionar **Cambio de director**, elegir Laura si figura apta, escribir motivo y enviar. | Se registra la solicitud pendiente; Natalia sigue siendo directora hasta su aprobación. |
| B2 | `demo.comite@grado.example` | Abrir la solicitud recién creada, elegir **Aprobar y aplicar**, responder y guardar. | Se cierra la asignación anterior y se registra la nueva. Verificar en Resumen quién tiene la función vigente. |
| B3 | `demo.est.felipe@grado.example` | Solicitar **Cambio de evaluador** hacia Marcela si figura apta, con un motivo. | El cambio no se aplica al enviar la solicitud. |
| B4 | `demo.comite@grado.example` | Aprobar y aplicar la solicitud del paso B3. | El resumen muestra a la nueva evaluadora y las asignaciones anteriores se conservan en el historial. Las revisiones posteriores deben seguir al responsable vigente. |

### C. Retiro de un participante y cancelación del último

Condición: proyecto 13 activo con Nicolás y Daniela como participantes vigentes. Si alguno ya se retiró, revisar el estado antes de continuar. Este caso puede cancelar el proyecto y liberar su idea.

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| C1 | `demo.est.daniela@grado.example` | En solicitudes del proyecto 13, elegir **Mi retiro del proyecto**, escribir motivo y enviar. | La solicitud corresponde a Daniela y queda pendiente; todavía no se elimina su participación. |
| C2 | `demo.comite@grado.example` | Aprobar y aplicar el retiro de Daniela. | Se cierra su participación; Nicolás permanece y el proyecto continúa mientras conserve un participante vigente. |
| C3 | `demo.est.nicolas@grado.example` | Solo si se quiere demostrar cancelación, solicitar también su retiro. | La cancelación no ocurre solamente por enviar la solicitud. |
| C4 | `demo.comite@grado.example` | Aprobar el retiro del último participante; consultar después el banco. | El proyecto queda cancelado y su idea vuelve a estar disponible. Los datos históricos no se borran. |

### D. Borrador, aprobación y consulta de actas

Condición: proyecto 15 no pausado y Juliana vinculada. Usar un número nuevo, por ejemplo `DEMO-EXPO-001`, cambiándolo si ya existe. Anotar la URL del acta creada como **URL-ACTA**.

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| D1 | `demo.comite@grado.example` | En `/actas.jsp?id=15`, desplegar **Registrar un acta nueva**, completar número, fecha, descripción y detalles; pulsar **Registrar acta**. | El acta se guarda como borrador pendiente de aprobación, vinculada al proyecto. |
| D2 | `demo.est.juliana@grado.example` | Consultar Actas del proyecto 15 e intentar URL-ACTA antes de aprobarla. | No puede consultar el contenido del borrador como si fuera un acta aprobada. |
| D3 | `demo.comite@grado.example` | Volver a URL-ACTA y pulsar **Aprobar acta**. | Se registran responsable y fecha de aprobación y se generan los avisos correspondientes. |
| D4 | `demo.est.juliana@grado.example` | Volver a Actas del proyecto 15 y abrir el acta aprobada. | Puede consultar su contenido y utilizar Imprimir del navegador si desea guardarla. |
| D5 | `demo.comite@grado.example` | Intentar crear otra acta con el mismo número. | La operación rechaza el número duplicado; no crea una segunda acta con ese identificador institucional. |

### E. Registro, correo único y recuperación de una cuenta inactiva

Usar una cuenta nueva ajena a los casos principales; guardar sus credenciales por separado. No desactivar las cuentas DEMO necesarias para la exposición ni la propia cuenta del Comité.

| # | Usuario | Acción | Qué debe ocurrir |
|---|---|---|---|
| E1 | Sin sesión | Registrar un estudiante con correo ficticio nuevo `@grado.example` y contraseña válida; iniciar sesión. | Queda activo automáticamente y puede ingresar sin aprobación manual ni correo. |
| E2 | Sin sesión | Intentar registrar otro usuario con el mismo correo, variando solo mayúsculas. | Se rechaza el duplicado por la unicidad de `lower(correo)`. |
| E3 | `demo.comite@grado.example` | Buscar la cuenta adicional en **Administrar cuentas** y cambiarla a inactiva. | Se revocan sus accesos; esto no pausa proyectos ni cambia sus contraseñas. |
| E4 | Cuenta adicional | Intentar ingresar con su contraseña correcta. | El estado inactivo impide el acceso autorizado. |
| E5 | `demo.comite@grado.example` | Reactivar la cuenta adicional. | Se habilita el inicio de una sesión nueva, conservando su contraseña e ID. |
| E6 | Cuenta adicional | Volver a ingresar con la contraseña original. | Puede entrar. Esto demuestra reactivación, no recuperación de una contraseña olvidada. |

El restablecimiento de una contraseña olvidada se realiza conforme a la sección 13 por el responsable técnico. No se presenta como un botón disponible en este guion ni se ejecuta sobre cuentas reales durante la exposición.

### F. Vencimientos automáticos y reglas temporales

Son casos de verificación del entorno aislado; no necesitan esperar días frente al profesor. No cambiar la fecha del servidor ni las fechas de proyectos de Supabase para reproducirlos. La suite prepara sus condiciones temporales en `grado_pruebas`.

| # | Usuario / entorno | Acción | Qué debe ocurrir |
|---|---|---|---|
| F1 | Responsable técnico / pruebas aisladas | Ejecutar `python -u scripts/pruebas_completas.py` desde la raíz, después de comprobar que se usará el entorno aislado. | Finaliza la suite o informa la comprobación que falló; no modifica los proyectos académicos de Supabase. |
| F2 | Caso de revisión docente vencida de la suite | Consultar el resultado del procesamiento del vencimiento de cinco días. | El trámite vuelve al estudiante y exige reenviar el conjunto para reiniciar con el director; no se aprueba automáticamente. |
| F3 | Caso de corrección vencida de la suite | Consultar el resultado del plazo de tres días y el intento de reenvío posterior. | Se genera el aviso, pero el estudiante puede reenviar si el resto de condiciones lo permite. |
| F4 | Casos de Informe I de la suite | Contrastar las pruebas de 90 días, 180 días y aprobación del informe por Comité. | Antes de habilitarse no se presenta; al vencimiento procede la cancelación cuando corresponde. La aprobación del informe por Comité evita la cancelación por ese plazo, aunque haya adicionales pendientes. |
| F5 | Caso de pausa de la suite | Revisar el ajuste de fechas y procesamiento de un proyecto pausado. | La pausa detiene el cómputo efectivo y la reanudación ajusta los límites; los plazos no se consumen como si hubiese permanecido activo. |

Estos casos se sustentan en las aserciones y el resultado de las pruebas, no en una afirmación de que el guion visual de 20 pasos haya ejecutado todos los vencimientos.

### Hoja breve de resultados alternos

| Caso | Resultado observado / incidencia |
|---|---|
| A. Pausa y reanudación | Pendiente de ejecutar. |
| B. Cambio de docentes | Pendiente de ejecutar. |
| C. Retiro y liberación de idea | Pendiente de ejecutar. |
| D. Actas y número único | Pendiente de ejecutar. |
| E. Autoactivación, correo único y reactivación | Pendiente de ejecutar. |
| F. Plazos en pruebas aisladas | Pendiente de ejecutar o adjuntar el informe técnico correspondiente. |
