# Base de datos del sistema de proyectos de grado

Motor: **PostgreSQL**. Esquema: `grado`. Modelo actualizado con las respuestas del usuario del 16 de octubre de 2026. Las decisiones de `docs/DECISIONES_FUNCIONALES.md` prevalecen sobre los puntos contradictorios del SDD original, que se conserva sin modificaciones.

## Archivos y ejecución

Desde la raíz, en una base vacía y con permisos para crear esquemas:

```powershell
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database/001_estructura.sql
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database/002_catalogos.sql
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database/003_verificacion.sql
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database/004_utilidades.sql
psql -X -v ON_ERROR_STOP=1 -d nombre_base -f database/005_verificacion_utilidades.sql
```

001, 002 y 004 se ejecutan una sola vez; cada archivo usa su propia transacción. No eliminan datos existentes. 003 está pensado para una base de desarrollo recién creada: verifica restricciones y revierte sus datos, aunque puede consumir valores de secuencias. 005 verifica las utilidades y los hashes sin crear cuentas. 004 requiere poder habilitar `pgcrypto` en el esquema `extensions`; si ya existe en otro esquema, se detiene sin reubicarla. Usar credenciales externas al repositorio. Son scripts de instalación inicial, no migraciones para una base que ya tenga estos objetos.

**Validación:** revisión estática realizada. Ejecución real pendiente: no hay `psql`/`postgres` instalado ni un motor Docker iniciado en este entorno. No se presenta el modelo como probado en PostgreSQL ni como implementación completa de las reglas funcionales.

## Entidades

| Grupo | Tablas | Propósito |
| --- | --- | --- |
| Acceso | `rol`, `usuario` | Un rol por cuenta, datos personales, registros estudiantil/docente autoactivados y credenciales mediante hash. |
| Perfil y aptitud | `perfil_docente`, `area_experiencia`, `modalidad`, `linea_investigacion`, `docente_area`, `docente_modalidad`, `docente_linea` | Varias áreas, modalidades y líneas por docente. |
| Ideas | `idea`, `decision_idea` | Ideas de docentes o estudiantes y decisiones del Comité. |
| Proyectos | `proyecto`, `participante_proyecto`, `asignacion_proyecto` | Idea reservada, integrantes y docentes asignados con historial. |
| Pausas | `pausa_proyecto` | Inicio, fin, motivo y responsables de cada desactivación y reanudación. |
| Fases | `fase`, `proyecto_fase` | Las seis fases y sus fechas/resultados por proyecto. |
| Documentos | `tipo_documento`, `documento`, `documento_version` | Documento lógico y versiones de su URL. |
| Entregas y revisión | `entrega_revision`, `entrega_documento_version`, `ciclo_revision`, `revision_entrega`, `plazo_correccion` | Conjunto de versiones presentado por el estudiante, revisión en cadena y reenvíos. |
| Entregas especiales | `datos_pago`, `entrega_final` | Director preferido, licencia y registro del repositorio. |
| Trámites | `solicitud`, `respuesta_solicitud`, `acta`, `acta_proyecto` | Solicitudes, decisiones y actas institucionales. |
| Comunicación | `mensaje`, `notificacion` | Mensajes y avisos dentro del sistema; no hay envío de correo. |
| Historial | `evento_auditoria` | Actor, fecha, proyecto, acción y cambios. |

Las claves de entidades son `bigint` autogeneradas; los catálogos estables usan códigos. Los eventos usan `timestamptz`; las actas tienen una fecha `date`. Configurar la sesión y la presentación de fechas con `America/Bogota` para el cálculo de días calendario.

## Relaciones y comportamiento

- Una idea puede estar reservada por un solo proyecto no cancelado. El índice parcial `proyecto_reserva_idea` permite volver a elegirla después de cancelar el proyecto anterior, conservando su relación histórica. El banco debe mostrar solo ideas aprobadas sin reserva vigente.
- Cada estudiante puede tener una participación vigente en un solo proyecto. Hay dos plazas activas como máximo por proyecto. Los integrantes se especifican en Pago y sus datos presentados se conservan en `nombre_en_pago`, `documento_en_pago`, `correo_en_pago` y `telefono_en_pago`. Siguen vinculados a cuentas de estudiantes por FK; no se añade un sistema de invitaciones. Nombre/correo son obligatorios en esta estructura; documento/teléfono son opcionales. Un retiro cierra la participación y conserva su historial. Al finalizar o cancelar un proyecto, la operación de cierre debe terminar las participaciones vigentes para permitir un nuevo proyecto.
- Un proyecto tiene como máximo un director y un evaluador vigentes y deben ser personas diferentes. Las asignaciones anteriores se cierran con `fin_en`.
- Solo el Comité aprueba Pago, junto con la idea presentada o elegida. No se asignan director/evaluador antes de esa aprobación. `datos_pago.aprobado_por/aprobado_en` conserva el resultado y el trigger `comprobar_pago_antes_asignacion` bloquea asignaciones sin pago e idea aprobados y proyecto activo. El permiso para registrar la aprobación sigue siendo responsabilidad de la operación autorizada.
- `docente_apto_idea` es una vista que exige simultáneamente coincidencia de área, modalidad y línea, y una cuenta docente activa. No reserva ni asigna al docente. El formulario de asignación debe filtrar además por el rol de la función elegida.
- Una fase tiene resultado `aprobado`, `rechazado` o `aplicado`. `NULL` significa que todavía no hay resultado. Sus fechas distinguen si no ha comenzado, está en curso o ha terminado. Solo puede estar en curso una fase por proyecto.
- Los documentos principales se registran en Pago, Propuesta I o Informe I. Los opcionales pueden registrarse también en Final. Propuesta II e Informe II revisan las mismas versiones mediante la entrega; no se duplican documentos para volver a evaluarlos.
- Una entrega contiene una versión concreta de cada documento incluido. Las claves compuestas impiden mezclar proyectos, asociar una versión a otro documento o incluir dos versiones del mismo documento en el conjunto.
- Las revisiones de propuesta/informe siguen Director → Evaluador → Comité sobre el conjunto. Pago es una excepción explícita: lo revisa únicamente el Comité, sin exigir revisiones de docentes aún no asignados. Una decisión del Comité se refiere al conjunto, no a decisiones independientes por archivo. El modelo conserva un reporte de texto por decisión.
- Cada corrección debe presentar otra vez todo el conjunto, con versiones registradas en la nueva entrega, conservando las anteriores. El nuevo ciclo comienza con el director. Tras vencimiento de revisión pueden utilizarse los mismos enlaces, pero se registra el reenvío completo; no constituye una aprobación.
- Cualquier enlace web HTTP/HTTPS es válido sin restricción de extensión o proveedor. No se comprueba su contenido mediante SQL ni se garantiza que el proveedor permita previsualizarlo. Se descartan esquemas ejecutables como `javascript:`.
- Comprobante, manual y evidencia usan documentos versionados. Licencia y repositorio se guardan en `entrega_final`, junto con quién registró el repositorio y cuándo.
- Los documentos adicionales usan el tipo `adicional` y una etiqueta descriptiva. Pueden registrarse varios por fase, también en Final. Manual, licencia y evidencia de publicación son opcionales en la aclaración más reciente, también para software: se conservan espacios para registrarlos cuando un docente o el Comité los soliciten. Se elimina la obligatoriedad automática de RN-11/RF-36; no se bloquea el avance por su ausencia. Los formatos principales de propuesta/informe siguen siendo requeridos.
- Si el proveedor impide la previsualización, la vista ofrecerá abrir el enlace en otra pestaña.
- Las notificaciones guardan destinatario, asunto, cuerpo, fecha y lectura. No hay destinatario de correo, estado de envío, reintentos ni integración SMTP.

## Fases y plazos confirmados

| Orden | Fase | Actividad |
| --- | --- | --- |
| 1 | Pago | Participantes, URL del comprobante, datos e idea del proyecto, y preferencia de director. Aprueba solo el Comité; después se asignan docentes. |
| 2 | Propuesta I | Entrega F-DC-124 y Turnitin al director. |
| 3 | Propuesta II | Continúa la revisión por evaluador y Comité del conjunto de la propuesta. |
| 4 | Informe I | Inicia el cómputo de vigencia; tras 90 días se permite entregar F-DC-125, F-DC-129 y Turnitin al director. |
| 5 | Informe II | Continúa la revisión por evaluador y Comité del conjunto del informe. |
| 6 | Final | Espacio para entregables finales opcionales y cierre del proyecto. |

Todos los plazos son de días calendario: 3 para corregir, 5 para revisión de director/evaluador, 90 de espera y 180 hasta cancelación desde el inicio de Informe I. Después de 3 días se avisa y se permite corregir. No se calculan festivos. Las fechas límite vencen a las **23:59:00 de Bogotá** del último día; el día del evento es día cero. `limite_dias_calendario` calcula ese instante. La habilitación del informe ocurre al comenzar el día 90 local mediante `habilitacion_informe`.

`inicio_vigencia_en` se registra una vez al aprobar el Comité Propuesta II e iniciar Informe I en la misma operación. `informe_habilitado_en` comienza con la habilitación a los 90 días y `vence_en` con el límite de 180 días al cierre del día. Un `CHECK` exige las tres fechas juntas y en orden. No se exige una diferencia exacta de intervalos porque las fechas efectivas deben ajustarse por pausas y cierre de día. Un rechazo o reinicio no reinicia el reloj. Antes de Informe I las tres son nulas.

Desactivar congela todos los procedimientos y plazos. `pausa_proyecto` conserva cada período y permite una sola pausa abierta por proyecto. Al reanudar se debe desplazar cada fecha pendiente por el tiempo pausado, manteniendo los vencimientos a las 23:59 y conservando la fecha inicial y el historial. No cambiar decisiones ya emitidas ni revivir plazos vencidos antes de la pausa. Las operaciones de pausa/reanudación, su autorización y los ajustes aún deben implementarse de forma transaccional; los índices no realizan esos ajustes por sí solos. El proceso programado debe excluir proyectos desactivados, y las vistas deben impedir acciones de trámite mientras dure la pausa.

El estado del proyecto distingue `activo`, `desactivado`, `cancelado` y `finalizado`. `informe_aprobado_comite_en` registra la aprobación del informe por el Comité: desde ese momento deja de aplicar la cancelación por los 180 días, aunque falten adicionales o el proyecto esté en Final. Las fechas originales se conservan como historial. El vencimiento solo debe cancelar proyectos activos sin esa aprobación.

## Qué garantiza el SQL y qué falta

El SQL ya impone unicidad de correo sin distinguir mayúsculas, reserva de idea, límites de participantes/asignaciones, separación de director y evaluador, referencias consistentes entre entregas y documentos, una fase en curso, numeración de versiones/ciclos, reporte obligatorio al aprobar/rechazar, fechas coherentes y avisos únicos por evento/destinatario.

Todavía se debe implementar la operación transaccional de cada caso de uso. En particular:

1. Autenticación y autorización. Estudiantes, directores y evaluadores se autoactivan al registrarse, por decisión expresa del aula. El trigger transforma el estado inicial pendiente en activo para esos tres roles; no reactiva cuentas existentes. El Comité mantiene la administración posterior de estados. No permitir autorregistro de Comité o Secretaría. Esta decisión sustituye RN-13 y el bloqueo de RF-01/RF-02 para registros nuevos; una clave foránea a `usuario` no verifica permisos.
2. La idea propia puede presentarse junto con Pago en un proyecto preliminar. El Comité debe aprobar idea y comprobante antes de habilitar la asignación docente o el avance. Las ideas del banco ya deben estar aprobadas. Crear participantes y seis fases de forma atómica.
3. Aplicar el orden de revisión, comprobar documentos requeridos, impedir saltos de fase y registrar correctamente las fases II sobre la entrega original.
4. Calcular límites de revisión/corrección; registrar `aplicado` y devolver la acción al estudiante; emitir alertas sin bloquear correcciones tardías; impedir entregas antes de 90 días y cancelar al llegar a 180 solo sin aprobación del informe por el Comité. Las operaciones deben ejecutarse incluso sin sesiones activas.
5. Resolver solicitudes de cambio/retiro por el Comité; conservar al compañero cuando un integrante se retira. Al aprobar el retiro del último integrante, cancelar el proyecto y devolver la idea al banco.
6. Permitir historial completo al Comité; estudiantes, director y evaluador solo para sus proyectos; Secretaría puede consultar el historial de los proyectos como parte de su función de consulta, sin modificarlo.
7. Permitir manual, licencia, repositorio y evidencia opcionales sin bloqueo por modalidad. Solo el Comité finaliza el proyecto; `finalizado_por` y `finalizado_en` conservan responsable y fecha. Un trigger exige que el responsable registrado sea una cuenta activa del Comité; la aplicación debe además autenticar que quien solicita el cierre sea esa persona y verificar los requisitos de avance.
8. Guardar cambios, auditoría y notificaciones en una transacción; evitar sobrescribir versiones o decisiones previas. La auditoría no se genera automáticamente para todas las tablas.

No se han configurado RLS, roles técnicos ni permisos del usuario de conexión. 004 aporta funciones para generar y verificar hashes bcrypt con `pgcrypto` (coste 12 y sal aleatoria). No constituye todavía un inicio de sesión: requiere consultas parametrizadas, conexión TLS y comprobación de estado/rol. No se permite ejecución pública de las dos funciones de contraseñas; se concederá al rol de conexión de la aplicación cuando se configure. No incluir hashes, contraseñas o tokens en los JSON de auditoría. Referencia: https://www.postgresql.org/docs/current/pgcrypto.html.

## Alcance técnico pendiente

Se utilizará VS Code, el proyecto de Supabase ya existente del usuario, repositorio GitHub más adelante y Tomcat para pruebas locales, con despliegue previsto en Vercel mediante Docker. No se ha conectado a Supabase ni creado recursos remotos desde este chat. JSTL se mantiene sin servlets propios, DAOs ni scriptlets. El usuario permite las etiquetas SQL de JSTL bajo esa condición; la vía prevista es JSTL SQL → JDBC PostgreSQL → Supabase, sin SDK JavaScript. La configuración de conexión sigue pendiente, no la elección de esa vía.

Al implementar la aplicación, sus dependencias se declararán con versiones fijadas en el proyecto y se incluirán en el artefacto/contenedor: JDK/Tomcat en la imagen, bibliotecas Jakarta JSTL y controlador JDBC en la aplicación. No se dependerá de JAR instalados manualmente en VS Code o XAMPP. Todavía no existe una aplicación web ni se han generado su WAR, imagen Docker o configuración de despliegue.

Supabase Cron es la propuesta para ejecutar reglas de vencimiento y generar avisos internos sin sesiones activas. Debe invocar una función transaccional de PostgreSQL que procese vencimientos, cambios, auditoría y notificaciones de forma idempotente. El esquema solo aporta las tablas e índices; ni esa función ni el trabajo Cron están implementados o activados aún. Referencia: https://supabase.com/docs/guides/cron.

Vercel documenta un runtime de contenedores OCI en beta, disponible en todos los planes. Tomcat dentro de un contenedor es una vía técnica por validar; no basta subir páginas JSP como archivos estáticos. Verificar arranque, compilación JSP, memoria y persistencia de sesiones ante escalado/reinicio antes de confirmar el despliegue. Referencia: https://vercel.com/docs/functions/runtimes/container. Esto no cambia la tecnología de vistas requerida.

Las funciones y triggers de fecha que ya contiene el script se ejecutan en PostgreSQL; no son clases Java ni componentes de la aplicación web. No se ha añadido una nueva arquitectura de aplicación para sortear la restricción.

## Trazabilidad

El modelo da soporte estructural a RF-01 a RF-41 según sus módulos. Las aclaraciones modifican RN-04/05/06/07/08, RF-15/20/22/23/24/25 y concretan RF-06/07/08/10/16/17/19/34/39. Véase `docs/DECISIONES_FUNCIONALES.md`. Este soporte no equivale al cumplimiento completo de los criterios funcionales ni de seguridad.
