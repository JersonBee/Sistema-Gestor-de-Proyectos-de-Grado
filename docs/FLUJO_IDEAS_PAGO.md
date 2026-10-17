# Recorrido implementado: idea → Pago → asignación

Disponible en `http://localhost:8080`, conectado a la base Supabase existente. Los registros hechos aquí son datos de esa base. Las pruebas y la captura del banco usaron exclusivamente `grado-pruebas`, en el puerto 8082.

1. **Registro.** Estudiantes y docentes crean su cuenta desde la página de acceso. El docente elige su único rol (director o evaluador) y registra modalidades, áreas y líneas. La activación es automática.
2. **Comité inicial.** Ejecutar `scripts/crear-comite.ps1` desde PowerShell, en la raíz del proyecto y con el contenedor iniciado. El usuario introduce nombre, correo y contraseña. No se crean credenciales predeterminadas, no se guarda la contraseña en un archivo y no se cambia una cuenta del Comité preexistente. Este comando aún no se ha ejecutado contra Supabase.
3. **Propuesta de idea.** Estudiante o director abre Banco de ideas → Proponer idea. Selecciona modalidad, área y línea e introduce título, descripción, objetivos y tecnologías. Puede elegir un área/línea existente mediante las sugerencias. La coincidencia docente usa los catálogos exactos.
4. **Revisión de idea.** El Comité abre el banco y el detalle de una idea pendiente. Guarda aprobación o rechazo con observaciones. Los demás usuarios solo pueden consultar ideas aprobadas; cada autor puede consultar sus propias propuestas pendientes/rechazadas. La decisión se conserva y se notifica al autor.
5. **Inicio del proyecto.** Un estudiante elige una idea aprobada y disponible, confirma sus datos y, si trabaja en pareja, registra los del segundo integrante. Su correo debe corresponder a una cuenta estudiantil activa. Puede indicar un director preferido apto. Crear el proyecto reserva la idea y abre Pago; todavía no asigna docentes.
6. **Pago.** El estudiante abre la fase desde el detalle del proyecto y registra el enlace del comprobante. Puede añadir enlaces adicionales opcionales, uno por línea. El envío fija un conjunto de versiones; no se permite presentar otro mientras esté pendiente de revisión.
7. **Decisión del Comité.** El Comité consulta participantes, preferencia de director y todos los enlaces de la entrega. Aprueba o solicita corrección del conjunto, con reporte escrito. No aprueba documentos individualmente.
8. **Corrección.** Se conserva la entrega rechazada y se abre un plazo de corrección de tres días calendario. El estudiante reenvía el conjunto completo, incluidos los adicionales que deban revisarse. Puede usar los mismos enlaces. El formulario no bloquea por demora. La alerta automática al vencer aún depende del módulo Cron pendiente.
9. **Asignación.** Después de aprobar Pago, el Comité selecciona un director y un evaluador distintos entre los docentes aptos por coincidencia conjunta de modalidad, área y línea. La asignación cierra Pago e inicia Propuesta I en una transacción. Se avisa a participantes y docentes.

La fase Pago permanece visible como fase actual mientras se espera la asignación. Su estado de aprobación se muestra por separado. Un proyecto desactivado no admite estos trámites.

Director y evaluador consultan los proyectos que tienen asignados. Cada estudiante consulta sus proyectos; el Comité y Secretaría tienen acceso de lectura general. Secretaría no puede decidir ni asignar. Las funciones SQL vuelven a validar sesión, rol, propiedad y estado del proyecto al escribir.

Las migraciones `006_acceso.sql` y `007_ideas_pago.sql` son aditivas. Los scripts originales no deben volver a ejecutarse sobre la base instalada. La suite local completa se ejecuta con `python scripts/pruebas_flujo_inicial.py`.

Los envíos/revisiones de Propuesta e Informe, Cron, pausas y avisos se implementaron después de este bloque; véase `REVISIONES_Y_PLAZOS.md`. Los entregables/cierre de Final y las solicitudes están en `CIERRE_Y_SOLICITUDES.md`. Para el estado global vigente consultar `README.md`. La aplicación no está desplegada en Vercel ni publicada en GitHub.
