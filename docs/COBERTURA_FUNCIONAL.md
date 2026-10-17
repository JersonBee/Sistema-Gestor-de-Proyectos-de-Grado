# Cobertura del alcance acordado

Se usa el SDD como referencia, con las aclaraciones de `DECISIONES_FUNCIONALES.md` por encima de sus reglas originales. Este documento relaciona funcionalidades y pruebas; no declara realizado un despliegue público.

| Requisitos del SDD | Implementación | Prueba principal |
| --- | --- | --- |
| RF-01, RF-02, RF-03 | Registro estudiantil/docente autoactivo; acceso; administración posterior de rol/estado por el Comité; asignaciones desde Pago y solicitudes. | `pruebas_acceso.py`, `pruebas_comunicacion.py`, `pruebas_final_solicitudes.py` |
| RF-09 | Perfil docente al registrarse; áreas, líneas y modalidades múltiples, cursos, títulos y temas. | `pruebas_acceso.py`, `pruebas_flujo_inicial.py` |
| RF-04, RF-05, RF-06, RF-10 | Ideas propias o de director, decisión del Comité, banco aprobado y docentes aptos por coincidencia de modalidad/área/línea. | `pruebas_flujo_inicial.py` |
| RF-07, RF-08, RF-12 | Proyecto individual/pareja, datos en Pago, comprobante y preferencia, aprobación del conjunto, reserva única y asignación de docentes distintos. | `pruebas_flujo_inicial.py` |
| RF-11, RF-13, RF-14, RF-15, RF-21, RF-30 | Seis fases; formatos y Turnitin; adicionales opcionales; enlaces web sin exigir extensiones; resultados por fase. | `pruebas_revisiones.py` |
| RF-16, RF-17, RF-18, RF-19 | Conjunto versionado y cadena director/evaluador/Comité; reporte obligatorio; previsualización y enlace externo. | `pruebas_revisiones.py` |
| RF-22, RF-23, RF-24, RF-25 | Corrección de tres días con alerta, revisión de cinco días, espera de 90 y vigencia de 180 desde Informe I; todos calendario; correcciones reinician desde director. | `pruebas_revisiones.py` |
| RF-26, RF-27, RF-32 | Cambio de docentes con preferencia, retiro individual/pareja, solicitudes/quejas/reclamos y decisión del Comité. | `pruebas_final_solicitudes.py` |
| RF-28 | Actas pendientes, aprobación y consulta autorizada con responsables y fecha. | `pruebas_comunicacion.py` |
| RF-20, RF-35 | Avisos dentro del sistema, sin correo; mensajes privados estudiante/director con lectura por destinatario. | Suites de revisiones, solicitudes y comunicación |
| RF-29, RF-31, RF-33, RF-34, RF-39, RF-41 | Detalle, pausa/reanudación y ajuste de plazos; Secretaría de consulta; historial y fechas automáticas, con acceso vigente/histórico. | Suites de acceso, revisiones, solicitudes y comunicación |
| RF-38 | Resumen con fase, responsable, siguiente acción, documentos pendientes, plazos y estado, según las transiciones reales. | `pruebas_resumen.py` |
| RF-40 | Filtros por estudiante, director, evaluador, modalidad, estado, fase y fechas; título/número; consultas autorizadas y paginación. | `pruebas_comunicacion.py` |
| RF-36, RF-37 | Final: adicionales opcionales; repositorio por director; cierre exclusivo del Comité sin exigir adicionales. | `pruebas_final_solicitudes.py` |

La bandeja **Mis tareas** atiende RNF-01: identifica acciones por rol y ofrece acceso directo a la pantalla para atenderlas. `pruebas_tareas.py` verifica la lista durante las transiciones del proceso y ejecuta las suites anteriores. Véase `TAREAS_POR_ROL.md`.

## Acuerdos que sustituyen el SDD original

- Registro de estudiantes y docentes autoactivo, con un solo rol.
- Enlaces sin restricción de extensión; documentos adicionales opcionales.
- Días calendario; la corrección vencida solo alerta y permite reenviar.
- Vigencia desde el inicio de Informe I, cancelación a los 180 días, con ajuste por pausas.
- Avisos internos en lugar de correo.
- Cierre del Comité independiente de los adicionales de Final.
- Arquitectura MVC con controladores JSP/JSTL y modelo de consultas, sin servlets, DAOs ni scriptlets propios.

## Entrega técnica pendiente

El repositorio GitHub y el despliegue remoto quedan para el paso autorizado por el usuario; se ha trabajado y probado con Docker local. La entrega manual y los límites de las sesiones al escalar están documentados en `GITHUB_Y_VERCEL.md`. Se conserva la cuenta de conexión acordada para el trabajo de aula. Las pruebas funcionales locales no sustituyen una prueba del runtime de despliegue ni la validación del usuario con sus casos académicos.
