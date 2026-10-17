# SDD — Sistema de Gestión de Proyectos de Grado

> **Documento de especificación para desarrollo guiado por especificaciones (Spec-Driven Development).**
> Pégalo (o adjúntalo) a tu asistente IA como contexto base. Cada requerimiento tiene ID, criterios de aceptación y tareas trazables.

---

## 0. Instrucciones para el asistente IA

**Rol:** Eres un desarrollador web que implementa este sistema siguiendo estrictamente esta especificación.

**Reglas de trabajo:**

1. La especificación (secciones 2 a 5) es la **fuente de verdad**. No agregues funcionalidades que no estén aquí.
2. Respeta la **Constitución** (sección 1) en todo momento; si una tarea parece exigir romperla, **detente y pregúntame**.
3. Trabaja **una tarea a la vez** (sección 7), en el orden indicado, y cita siempre los IDs (`RF-xx`, `RN-xx`, `RNF-xx`) que cubres.
4. Antes de implementar cada tarea, confirma los criterios de aceptación; al terminar, verifica cada uno.
5. Si encuentras una ambigüedad, consulta la sección 8 (Puntos abiertos) y pregúntame antes de decidir.
6. Entrega código **completo, documentado y ejecutable**, con nombres, comentarios y textos en **español**.

---

## 1. Constitución (restricciones no negociables)

| ID | Restricción |
| --- | --- |
| C-01 | Las vistas se construyen **exclusivamente con JSTL de Jakarta (versión 2026)**. |
| C-02 | **Prohibido:** scriptlets, servlets, DAOs y fragmentos JSPF. |
| C-03 | **JavaScript solo en la vista Landing Page.** En ninguna otra vista. |
| C-04 | **No hay carga de archivos.** Los documentos se registran como **URL** y se previsualizan sin descarga obligatoria. |
| C-05 | Cada usuario accede **solo** a las funciones de su rol. |
| C-06 | Interfaz en español. |

**Fuera de alcance (eliminado respecto a la versión anterior):**

- Solicitud de prórroga y auditoría de prórrogas.
- Resultados y exoneración/beneficios por TyT.
- Asistente informativo (no IA).
- Carga de archivos (reemplazada por registro de URLs).

---

## 2. Contexto y actores

**Propósito:** gestionar el ciclo completo de proyectos de grado: banco de ideas, creación y asignación de proyectos, fases de seguimiento con revisión de documentos, solicitudes, actas, historial y comunicación entre los involucrados.

**Formato de los requerimientos:** *"El usuario [rol] en la vista [vista] debe poder [acción]"*.

### 2.1 Roles

| Rol | Descripción |
| --- | --- |
| Visitante | Usuario sin sesión; solo ve la Landing Page. |
| Estudiante | Crea su cuenta, elige o propone idea, gestiona su proyecto, registra URLs, envía solicitudes. |
| Director | Registra ideas, tiene perfil docente, revisa documentos, registra el repositorio final. |
| Evaluador | Tiene perfil docente y revisa documentos. |
| Comité / Coordinador | Activa cuentas, aprueba ideas, asigna director y evaluador, revisa, genera actas, desactiva proyectos. |
| Secretaría | Consulta información y progreso de proyectos para atender consultas. |
| Sistema | Reglas automáticas: validaciones, plazos, notificaciones, registro de fechas. |

### 2.2 Vistas

Landing Page · Registro · Gestión de Usuarios · Banco de Ideas · Revisión de Ideas · Propuesta de Idea · Creación de Proyecto · Asignación de Proyecto · Perfil Docente · Fases de Seguimiento · Fase Pago · Fase Propuesta I · Fase Informe I · Fase Rechazada · Fase Final · Revisión de Documento · Notificaciones · Solicitudes · Actas · Detalles del Proyecto · Proyectos · Historial · Mensajes · Resumen del Proyecto.

### 2.3 Glosario

| Término | Significado |
| --- | --- |
| Fases | Pago → Propuesta I → Propuesta II → Informe I → Informe II → Final. |
| Estados de fase | `aprobado`, `rechazado`, `aplicado`. |
| F-DC-124 / F-DC-125 / F-DC-129 | Formatos institucionales (.docx) entregados por URL. |
| Reporte Turnitin | Documento (.pdf) entregado por URL. |
| Reporte de respuesta | Respuesta obligatoria al aprobar o rechazar un formato. |
| Modalidad | Tipo de proyecto (p. ej. desarrollo de software). |
| Proyecto vencido/cerrado | Estado al cumplirse los 180 días del proyecto. |

---

## 3. Reglas de negocio transversales

| ID | Regla |
| --- | --- |
| RN-01 | El flujo de revisión es **Estudiante → Director → Evaluador → Comité**; no se puede omitir ninguna etapa. |
| RN-02 | Las fases son, en orden: Pago, Propuesta I, Propuesta II, Informe I, Informe II, Final. |
| RN-03 | Cada fase muestra un estado: aprobado, rechazado o aplicado. |
| RN-04 | Una fase rechazada se corrige y reenvía (nueva URL) en máximo **3 días hábiles**. |
| RN-05 | Director y Evaluador tienen máximo **5 días hábiles** para revisar; si vence, el estado pasa a *aplicado* y el ciclo de revisión se reinicia. |
| RN-06 | El F-DC-125 no puede entregarse antes de **90 días** desde la aprobación del F-DC-124 por el Comité. |
| RN-07 | El proyecto tiene **180 días**; al cumplirse pasa a vencido/cerrado. |
| RN-08 | URLs permitidas: **.docx** para formatos institucionales y **.pdf** para Turnitin. |
| RN-09 | Aprobar o rechazar un formato exige un **reporte de respuesta**. |
| RN-10 | Un proyecto es individual o en pareja. Si un integrante se retira, el otro continúa de forma individual. |
| RN-11 | En modalidad desarrollo de software, la Fase Final exige URL del manual de usuario, tipo de licencia y evidencia de publicación en repositorio. |
| RN-12 | Una idea solo está disponible para estudiantes tras ser **aprobada por el Comité**. |
| RN-13 | La cuenta de un estudiante queda **pendiente** hasta que el Comité la active. |
| RN-14 | Director y Evaluador se asignan desde la **fase Pago**. |
| RN-15 | Un proyecto no avanza de fase si no se cumplen las condiciones requeridas. |

---

## 4. Especificación funcional (RF)

Formato: **Rol · Vista · Acción · Criterios de aceptación (CA)**.

### 4.1 Cuentas y usuarios

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-01 | Estudiante | Registro | Crear su cuenta con sus credenciales, quedando pendiente de activación por el Comité. | CA1: el registro crea la cuenta en estado *pendiente*. CA2: no puede iniciar sesión hasta ser activada (RN-13). |
| RF-02 | Comité | Gestión de Usuarios | Activar las cuentas de estudiantes registradas. | CA1: lista las cuentas pendientes. CA2: al activar, la cuenta queda habilitada. |
| RF-03 | Comité | Gestión de Usuarios | Administrar usuarios, roles, estados de cuenta y asignaciones. | CA1: puede cambiar rol y estado de una cuenta. CA2: puede gestionar asignaciones de usuarios. |
| RF-09 | Director y Evaluador | Perfil Docente | Registrar área de experiencia, cursos, títulos académicos, temas de preferencia y modalidades que trabajan. | CA1: el formulario contempla los cinco campos. CA2: los datos quedan asociados al docente. |

### 4.2 Ideas

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-04 | Director | Banco de Ideas | Registrar una idea con modalidad, descripción, línea de investigación, título, objetivos y tecnologías. | CA1: el formulario contempla los seis campos. CA2: la idea queda pendiente de revisión. |
| RF-05 | Comité | Revisión de Ideas | Aprobar o rechazar ideas antes de ponerlas disponibles para estudiantes. | CA1: solo las ideas aprobadas aparecen a los estudiantes (RN-12). CA2: cada decisión queda registrada. |
| RF-06 | Estudiante | Banco de Ideas / Propuesta de Idea | Seleccionar una idea aprobada; y registrar una idea propia según el proceso establecido. | CA1: solo ve ideas aprobadas. CA2: la vista Propuesta de Idea permite registrar una idea propia. |
| RF-10 | Estudiante | Banco de Ideas | Visualizar los docentes aptos para trabajar cada idea. | CA1: cada idea muestra los docentes aptos según su perfil (RF-09). |

### 4.3 Proyecto y asignación

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-07 | Estudiante | Creación de Proyecto | Gestionar los participantes del proyecto, individual o en pareja. | CA1: permite proyecto individual o de dos integrantes (RN-10). |
| RF-08 | Comité | Asignación de Proyecto | Asignar director y evaluador desde la fase Pago según las reglas establecidas. | CA1: la asignación se realiza desde la fase Pago (RN-14). CA2: el proyecto muestra director y evaluador asignados. |
| RF-29 | Usuario autorizado | Detalles del Proyecto | Consultar la idea, los participantes y el director del proyecto. | CA1: muestra los tres datos. CA2: solo accede quien tiene permiso. |
| RF-38 | Estudiante | Resumen del Proyecto | Visualizar fase actual, responsable de la siguiente acción, documentos pendientes, fechas límite y estado general. | CA1: la vista muestra los cinco datos. |

### 4.4 Fases y registro de URLs

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-11 | Estudiante, Director, Evaluador, Comité | Fases de Seguimiento | Visualizar las fases: Pago, Propuesta I, Propuesta II, Informe I, Informe II y Final. | CA1: se muestran las seis fases en orden (RN-02). |
| RF-12 | Estudiante | Fase Pago | Registrar la URL del comprobante de pago junto con título, objetivos y descripción, y proponer un director de su preferencia. | CA1: el formulario recibe URL, título, objetivos, descripción y director propuesto. |
| RF-13 | Estudiante | Fase Propuesta I | Registrar la URL del formato F-DC-124 y la URL del reporte Turnitin. | CA1: dos campos URL. CA2: validación según RF-15. |
| RF-14 | Estudiante | Fase Informe I | Registrar las URLs del F-DC-125, del F-DC-129 y del reporte Turnitin. | CA1: tres campos URL. CA2: validación según RF-15. |
| RF-15 | Sistema | Vistas de registro de URLs | Validar que los enlaces correspondan a los tipos permitidos (.docx formatos, .pdf Turnitin). | CA1: rechaza URL con extensión no permitida (RN-08). CA2: muestra mensaje de error claro. |
| RF-21 | Sistema | Fases de Seguimiento | Mostrar el estado de cada fase: aprobado, rechazado o aplicado. | CA1: cada fase muestra su estado (RN-03). |
| RF-30 | Estudiante, Director, Evaluador, Comité | Fases de Seguimiento | Consultar el progreso detallado de cada proyecto. | CA1: detalle por fase y por proyecto. |

### 4.5 Revisión de documentos

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-16 | Sistema | Fases de Seguimiento | Controlar el flujo Estudiante → Director → Evaluador → Comité, impidiendo omitir etapas. | CA1: un documento no pasa a la siguiente etapa sin aprobar la anterior (RN-01). |
| RF-17 | Director, Evaluador, Comité | Revisión de Documento | Aprobar o rechazar los documentos correspondientes a su rol. | CA1: cada rol solo actúa sobre lo que le corresponde en el flujo. |
| RF-18 | Usuario autorizado | Revisión de Documento | Visualizar el archivo a partir de su URL sin descarga obligatoria. | CA1: el documento se previsualiza en la misma vista (C-04, RNF-07). |
| RF-19 | Director, Evaluador, Comité | Revisión de Documento | Generar un reporte de respuesta obligatorio al aprobar o rechazar un formato. | CA1: no se puede aprobar ni rechazar sin reporte (RN-09). |
| RF-22 | Estudiante | Fase Rechazada | Corregir y reenviar la URL del formato dentro de 3 días hábiles. | CA1: permite reenviar dentro del plazo. CA2: pasado el plazo, bloquea el reenvío (RN-04). |
| RF-23 | Sistema | Revisión de Documento | Controlar el tiempo máximo de revisión de Director y Evaluador (5 días hábiles); al vencer, cambiar estado a *aplicado* y reiniciar el ciclo. | CA1: al vencer el plazo, estado = aplicado. CA2: el ciclo de revisión se reinicia (RN-05). |
| RF-24 | Sistema | Fase Informe I | Impedir la entrega del F-DC-125 antes de 90 días desde la aprobación del F-DC-124 por el Comité. | CA1: antes de los 90 días, el registro está bloqueado (RN-06). |
| RF-25 | Sistema | Fases de Seguimiento | Controlar los 180 días del proyecto y determinar cuándo pasa a vencido/cerrado. | CA1: al cumplirse los 180 días, el estado es vencido/cerrado (RN-07). |

### 4.6 Solicitudes, actas y mensajes

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-26 | Estudiante | Solicitudes | Solicitar cambio de director o evaluador, indicando su preferencia. | CA1: el formulario incluye la preferencia. |
| RF-27 | Estudiante | Solicitudes | Solicitar el retiro del proyecto, contemplando proyectos en pareja donde el otro integrante continúa individual. | CA1: en proyecto en pareja, el otro integrante continúa solo (RN-10). |
| RF-28 | Comité | Actas | Generar y registrar actas con número, fecha, descripción, detalles y aprobación del Comité. | CA1: el acta contiene los cinco campos. |
| RF-32 | Estudiante | Proyectos | Enviar reclamos, quejas o solicitudes al Comité. | CA1: el Comité recibe el mensaje enviado. |
| RF-35 | Estudiante, Director | Mensajes | Comunicarse mediante un canal interno de la plataforma. | CA1: ambos pueden enviar y leer mensajes. |
| RF-20 | Sistema | Notificaciones | Notificar por correo a los involucrados cuando se registre un documento o cambie el estado de una solicitud. | CA1: se envía correo en ambos eventos. |

### 4.7 Consulta, historial y administración de proyectos

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-31 | Comité | Proyectos | Desactivar proyectos cuando corresponda. | CA1: el proyecto desactivado queda marcado como tal. |
| RF-33 | Secretaría | Proyectos | Consultar información y progreso de proyectos para atender consultas. | CA1: acceso de solo consulta. |
| RF-34 | Usuario autorizado | Historial | Consultar la auditoría de URLs registradas, respuestas recibidas, solicitudes y trámites. | CA1: muestra los cuatro tipos de registro. |
| RF-39 | Comité | Historial | Consultar el historial completo de estados, aprobaciones, rechazos y modificaciones de cada proyecto. | CA1: historial completo por proyecto. |
| RF-40 | Comité | Proyectos | Buscar y filtrar proyectos por estudiante, director, evaluador, modalidad, estado, fase y fechas. | CA1: los siete filtros funcionan, solos o combinados. |
| RF-41 | Sistema | Todas las vistas | Registrar automáticamente fechas de registro de URL, revisión, aprobación, rechazo y modificación de documentos. | CA1: cada evento guarda su fecha sin intervención del usuario. |

### 4.8 Fase Final

| ID | Rol | Vista | Debe poder | Criterios de aceptación |
| --- | --- | --- | --- | --- |
| RF-36 | Sistema | Fase Final | Exigir, en modalidad desarrollo de software, la URL del manual de usuario, el tipo de licencia y la evidencia de publicación en repositorio. | CA1: sin los tres datos no se completa la fase (RN-11). |
| RF-37 | Director | Fase Final | Registrar la URL del repositorio GitHub del proyecto finalizado. | CA1: el campo URL queda asociado al proyecto. |

---

## 5. Especificación no funcional (RNF)

| ID | Categoría | Requerimiento | Criterio de verificación |
| --- | --- | --- | --- |
| RNF-01 | Usabilidad | Cualquier rol identifica sus tareas pendientes, el estado del proyecto y las acciones disponibles. | Cada vista muestra pendientes, estado y acciones. |
| RNF-02 | Control de acceso | Cada rol accede solo a sus funciones (Estudiante, Director, Evaluador, Comité/Coordinador, Secretaría). | Un rol no puede abrir vistas ni acciones de otro. |
| RNF-03 | Seguridad | Credenciales y datos sensibles se almacenan y transmiten de forma segura. | Sin credenciales en texto plano. |
| RNF-04 | Integridad | Un proyecto no avanza a una fase sin cumplir las condiciones requeridas. | Cubre RN-15. |
| RNF-05 | Tecnología de vistas | Interfaz exclusivamente con JSTL de Jakarta 2026, sin scriptlets, servlets, DAOs ni JSPF. | Revisión del código: ninguno presente (C-01, C-02). |
| RNF-06 | JavaScript | JavaScript solo en la Landing Page para elementos dinámicos. | Ningún otro archivo contiene JS (C-03). |
| RNF-07 | Previsualización | El archivo se previsualiza desde su URL sin descarga obligatoria. | Cubre RF-18. |
| RNF-08 | Disponibilidad | Acceso durante los periodos establecidos para la gestión de proyectos. | Sistema accesible en dichos periodos. |
| RNF-09 | Rendimiento | Consulta, navegación y actualización en tiempos adecuados. | Operaciones habituales sin demoras notables. |
| RNF-10 | Trazabilidad | Registrar quién hizo qué, cuándo y sobre qué proyecto. | Cada operación relevante guarda usuario, fecha y proyecto. |
| RNF-11 | Escalabilidad | Incorporar proyectos, usuarios, modalidades, fases o trámites sin cambios estructurales importantes. | Agregar una modalidad o fase no exige rediseño. |
| RNF-12 | Compatibilidad | Funciona en navegadores web modernos. | Prueba en navegadores actuales. |
| RNF-13 | Mantenibilidad | Reglas, fases y trámites modificables de forma sencilla por organización modular. | Reglas centralizadas y modulares. |
| RNF-14 | Respaldo | Respaldar y recuperar información de proyectos y documentos. | Existe procedimiento de respaldo y recuperación. |
| RNF-15 | Confidencialidad | Documentos y datos de proyectos disponibles solo para usuarios autorizados. | Acceso denegado a no autorizados. |
| RNF-16 | Consistencia | Los cambios de estado se reflejan igual en vistas, historial y notificaciones. | Mismo estado en las tres fuentes. |
| RNF-17 | Accesibilidad | La interfaz es usable por personas con diferentes necesidades de acceso. | Interfaz accesible. |
| RNF-18 | Auditabilidad | Consultar posteriormente las acciones sobre documentos, solicitudes y trámites. | Cubre RF-34 y RF-39. |

---

## 6. Plan técnico

**Restricciones tecnológicas (derivadas de la Constitución):**

- Capa de vistas: páginas con **JSTL de Jakarta (2026)** únicamente (C-01, C-02).
- JavaScript: solo en la Landing Page (C-03).
- Documentos: campos URL + previsualización embebida; sin subida de archivos (C-04).
- Control de acceso por rol en cada vista (C-05).

**Decisiones por confirmar antes de implementar** (ver sección 8): base de datos, forma de acceder a datos sin DAOs/servlets, envío de correos, ejecución de plazos automáticos, framework CSS.

**Organización sugerida de módulos** (alineada con RNF-13):

| Módulo | Cubre |
| --- | --- |
| Acceso y usuarios | RF-01, RF-02, RF-03, RF-09, RNF-02, RNF-03 |
| Ideas | RF-04, RF-05, RF-06, RF-10 |
| Proyectos | RF-07, RF-08, RF-29, RF-31, RF-33, RF-38, RF-40 |
| Fases y documentos | RF-11 a RF-19, RF-21 a RF-25, RF-30, RF-36, RF-37 |
| Solicitudes y actas | RF-26, RF-27, RF-28, RF-32 |
| Comunicación | RF-20, RF-35 |
| Historial y auditoría | RF-34, RF-39, RF-41, RNF-10, RNF-18 |
| Landing | RNF-06 |

---

## 7. Tareas (orden de implementación)

Cada tarea se entrega completa y verificada contra sus criterios de aceptación antes de pasar a la siguiente.

| Tarea | Descripción | Cubre |
| --- | --- | --- |
| T-01 | Base: estructura del proyecto, layout común, roles y control de acceso por rol. | C-01 a C-06, RNF-02, RNF-05 |
| T-02 | Registro, inicio de sesión y activación de cuentas por el Comité. | RF-01, RF-02, RNF-03 |
| T-03 | Gestión de usuarios (roles, estados, asignaciones). | RF-03 |
| T-04 | Perfil docente. | RF-09 |
| T-05 | Banco de ideas: registro, revisión del Comité, selección, idea propia y docentes aptos. | RF-04, RF-05, RF-06, RF-10 |
| T-06 | Creación de proyecto y asignación de director y evaluador. | RF-07, RF-08 |
| T-07 | Fases de seguimiento: visualización, estados y progreso. | RF-11, RF-21, RF-30 |
| T-08 | Registro de URLs por fase con validación de tipo (Pago, Propuesta I, Informe I). | RF-12, RF-13, RF-14, RF-15 |
| T-09 | Revisión de documentos: previsualización, aprobar/rechazar, reporte de respuesta y flujo en cadena. | RF-16, RF-17, RF-18, RF-19 |
| T-10 | Plazos: corrección (3 días), revisión (5 días), espera (90 días) y vigencia (180 días). | RF-22, RF-23, RF-24, RF-25, RNF-04 |
| T-11 | Fase Final (manual, licencia, repositorio). | RF-36, RF-37 |
| T-12 | Solicitudes (cambio de director/evaluador, retiro, reclamos) y actas. | RF-26, RF-27, RF-28, RF-32 |
| T-13 | Consulta y administración de proyectos: detalles, resumen, búsqueda y filtros, desactivación, vista de Secretaría. | RF-29, RF-31, RF-33, RF-38, RF-40 |
| T-14 | Historial, auditoría y registro automático de fechas. | RF-34, RF-39, RF-41, RNF-10, RNF-18 |
| T-15 | Notificaciones por correo y mensajería interna. | RF-20, RF-35 |
| T-16 | Landing Page con JavaScript (única vista con JS). | RNF-06 |
| T-17 | Revisión transversal: usabilidad, accesibilidad, consistencia, confidencialidad, compatibilidad. | RNF-01, 07, 12, 15, 16, 17 |

---

## 8. Puntos abiertos (resolver con el asistente antes de implementar)

Estas tensiones surgen de combinar los requerimientos con las restricciones C-01 a C-03. No están resueltas en el documento original:

| # | Punto | Por qué importa |
| --- | --- | --- |
| P-01 | **Acceso a datos sin servlets ni DAOs** (C-02). | Hay que decidir cómo se consulta y guarda la información (p. ej. con las etiquetas SQL de JSTL). |
| P-02 | **Validación de URL sin JavaScript** (RF-15, C-03). | La validación de extensión .docx/.pdf debe hacerse del lado del servidor con JSTL. |
| P-03 | **Previsualización sin JavaScript** (RF-18, RNF-07). | Definir cómo se embebe el archivo desde la URL (p. ej. visor embebido). |
| P-04 | **Plazos automáticos** (RF-23, RF-25, RN-04 a RN-07). | Sin servlets ni tareas programadas, definir cuándo se evalúan (p. ej. al cargar la vista). |
| P-05 | **Envío de correos** (RF-20). | Definir cómo se envían sin servlets ni código Java. |
| P-06 | **Días hábiles**. | Definir si se consideran festivos o solo lunes a viernes. |
| P-07 | **Qué cuenta como "Evaluador" en el flujo de Fase Propuesta II e Informe II.** | El documento solo detalla el registro de URLs de Pago, Propuesta I e Informe I. |
| P-08 | **Quién puede ver el historial de RF-34** ("usuario con acceso autorizado"). | Definir roles con acceso. |

---

## 9. Definición de terminado (DoD)

Una tarea está terminada cuando:

- [ ] Cumple todos los criterios de aceptación de sus RF.
- [ ] Respeta las reglas de negocio (RN) asociadas.
- [ ] Cumple la Constitución (sin scriptlets, servlets, DAOs ni JSPF; JS solo en la landing).
- [ ] Está restringida por rol.
- [ ] El código es completo, documentado, en español y ejecutable.
- [ ] Se citan los IDs cubiertos en la entrega.
