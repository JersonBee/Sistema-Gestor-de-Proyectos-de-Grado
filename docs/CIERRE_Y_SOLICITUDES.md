# Fase Final, solicitudes e historial

Las páginas se abren desde **Detalle del proyecto → Final y trámites**. El contenedor principal usa Supabase en el puerto 8080. Las pruebas y capturas usan únicamente fixtures locales de `grado-pruebas`, en el puerto 8082.

## Entregables y cierre

Después de la aprobación de Informe II por el Comité, los estudiantes vigentes pueden registrar el manual de usuario, la evidencia de publicación y el tipo de licencia. El director actualmente asignado registra el enlace del repositorio. Se acepta cualquier enlace HTTP(S), sin exigir extensión o proveedor. Los cambios conservan versiones de documentos o el valor anterior en la auditoría.

Todos esos datos son opcionales. **Solo el Comité** finaliza un proyecto activo en fase Final con informe aprobado. Las observaciones de cierre son opcionales. El cierre:

- Aprueba y termina la fase Final y registra responsable y fecha.
- Cierra las participaciones/asignaciones, liberando a los estudiantes para otro proyecto.
- Conserva la reserva de la idea y todo el historial.
- Cierra solicitudes todavía pendientes como atendidas sin ejecutar los cambios pedidos, con explicación y aviso al solicitante. La pantalla lo indica antes de finalizar.
- Deja el proyecto disponible para consulta y rechaza nuevas escrituras sobre él.

El Comité no edita los entregables en nombre del estudiante o del director. Secretaría tiene acceso de lectura. Un participante retirado y un docente anterior conservan lectura histórica, pero no pueden modificar entregables ni revisiones pendientes.

## Solicitudes

Los estudiantes vigentes pueden solicitar cambio de director, cambio de evaluador, su propio retiro, atención de una solicitud general, queja o reclamo. Se exige motivo escrito. Los cambios incluyen un docente preferido activo y apto por modalidad, área y línea, del rol correspondiente y distinto de los docentes actualmente asignados. La aptitud se comprueba de nuevo al aprobar.

El Comité aprueba/rechaza cambios y retiros, y atiende/rechaza consultas generales con respuesta escrita. Los trámites de un proyecto pausado no pueden crearse ni resolverse. Antes de escribir se comprueba también si el proyecto ya venció.

Al aprobar un cambio se cierra la asignación anterior y se abre la nueva. Las revisiones ya respondidas se conservan. Si hay una revisión pendiente de la función cambiada, pasa al nuevo docente y obtiene cinco días calendario desde la reasignación. No se reinician revisiones de otras funciones ni la vigencia general del proyecto. El docente sustituido conserva la lectura histórica.

Al aprobar un retiro se cierra únicamente la participación del solicitante. Si queda su compañero, el proyecto continúa. Si no quedan integrantes, se cancela, se cierran las revisiones abiertas y la idea vuelve al banco. Los cambios/retiros pendientes del participante que salió se cierran sin aplicarse; los trámites pendientes de un proyecto cancelado también quedan cerrados, con explicación. Los cierres automáticos derivados de vencimiento/cancelación quedan auditados como acciones del sistema; no se inventa una persona responsable.

## Historial

`historial.jsp` muestra por proyecto las acciones, actor, hora de Bogotá y detalle, con paginación. El acceso usa los mismos permisos que la consulta del proyecto. Los documentos versionados se consultan en sus fases; las respuestas del Comité se conservan en Solicitudes. Las páginas escapan los textos escritos por usuarios.

## Validación

La migración aditiva `010_final_solicitudes.sql` se probó localmente y se aplicó a Supabase sin fixtures. El trabajo Cron existente permanece activo; un trigger cierra los trámites pendientes cuando el proyecto llega a un estado terminal, incluida la cancelación automática por vencimiento.

`python scripts/pruebas_final_solicitudes.py` ejecuta los módulos anteriores y comprueba adicionales opcionales, versiones, repositorio por director, cierre exclusivo del Comité, falta de adicionales sin bloqueo, retiro de uno/ambos integrantes, acceso posterior de lectura, rechazo de escrituras del retirado, reasignación de revisiones pendientes, respuesta obligatoria/escapada, pausa de trámites, cierre de solicitudes abiertas y conservación/liberación de la idea según finalización/cancelación.

`database/pruebas/final_opcional.sql` es una prueba local reversible y no se instala en Supabase.

Quedan pendientes actas, mensajería interna, administración posterior de cuentas y búsqueda/filtros generales de proyectos, además de preparar el despliegue público.
