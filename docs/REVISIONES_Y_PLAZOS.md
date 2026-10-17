# Recorridos y plazos implementados

Desde el detalle de un proyecto, abrir **Propuesta I / II** o **Informe I / II**. La pantalla indica la siguiente acción y permite consultar los documentos de la última entrega antes de decidir. Conserva las entregas y respuestas anteriores. Los enlaces se pueden abrir en otra pestaña; la previsualización usa un marco aislado y depende de que el proveedor permita mostrar el documento.

| Recorrido | Documentos obligatorios | Revisores |
| --- | --- | --- |
| Propuesta | F-DC-124 y Turnitin | Director → evaluador → Comité |
| Informe | F-DC-125, F-DC-129 y Turnitin | Director → evaluador → Comité |

Los adicionales son opcionales. Cada envío fija el conjunto completo de versiones y llega primero al director. Su aprobación cierra la fase I y abre la fase II, donde continúan evaluador y Comité sobre la misma entrega. Aprobar o rechazar requiere reporte escrito.

Un rechazo de cualquiera de los tres revisores termina el ciclo y reabre la fase I para que el estudiante reenvíe el conjunto completo al director. El historial conserva los reportes. Una decisión sobre una revisión terminada, de otra persona o fuera de la etapa correspondiente se rechaza en la base de datos.

El Comité funciona como revisor colectivo: cualquiera de sus cuentas activas puede resolver la revisión pendiente. El responsable se registra al decidir; no se asigna arbitrariamente una cuenta al abrir esa etapa. Las revisiones de director/evaluador exigen su asignación vigente. Los docentes conservan lectura histórica de los proyectos a los que estuvieron asignados, incluso tras la cancelación.

| Plazo | Comportamiento |
| --- | --- |
| 3 días calendario | Una corrección pendiente genera una alerta al vencer. El reenvío permanece permitido. Incluye las correcciones de Pago. |
| 5 días calendario | Director y evaluador deben responder. Al vencer, la revisión pasa a `aplicado` y vuelve al estudiante, sin aprobación automática. Puede reenviar los mismos enlaces al director. |
| Comité | No se impone el plazo docente de cinco días. |
| 90 días | Se cuentan desde el inicio de Informe I, en la misma transacción que aprueba Propuesta II. Antes de la fecha se bloquea la entrega de Informe I. Al habilitarla se emite un aviso una sola vez. |
| 180 días | Desde el mismo inicio de Informe I. Al llegar al límite, se cancela el proyecto, cierran las participaciones/asignaciones y la idea queda libre. La aprobación del Informe por el Comité detiene esta cancelación, aunque falten adicionales finales. |

El día del evento es día cero. Los límites de corrección, revisión y vigencia cierran a las **23:59 de America/Bogota**, incluidos fines de semana y festivos. La habilitación de Informe I comienza a las 00:00 de su fecha. El proceso automático se ejecuta cada minuto; las mutaciones de revisión también comprueban los vencimientos antes de aceptar una decisión.

## Pausa

El Comité puede pausar/reanudar desde el detalle del proyecto, dejando motivo e historial. Se detienen los trámites y el procesamiento de sus plazos mientras esté desactivado. Antes de pausar se procesan los vencimientos que ya correspondan.

La precisión técnica elegida para reponer tiempo es **un día calendario por cada día o fracción de pausa**. Así, 26 horas reponen dos días y los límites conservan sus horas de cierre. Solo se desplazan los plazos todavía pendientes al iniciar la pausa; no se reinicia la fecha histórica de Informe I ni una espera de 90 días ya cumplida. La pantalla del Comité explica esta regla antes de pausar.

## Ejecución y verificación

`008_revisiones_plazos.sql` instala funciones y campos de control, sin datos ficticios. `009_cron.sql` registra en Supabase el trabajo `grado-procesar-plazos`, una vez por minuto, que llama `grado.procesar_plazos()` sin depender de sesiones o de Tomcat. Repetir 009 actualiza ese mismo trabajo. No modifica otros trabajos Cron. Los avisos usan marcas de emisión y las transiciones bloquean el proyecto para impedir duplicados y decisiones concurrentes sobre estados antiguos.

Se verificó que el trabajo está activo y que existe una ejecución reciente correcta mediante `database/supabase/03_verificar_cron.sql` (solo lectura). Referencia de la implementación del programador: [documentación oficial de Supabase Cron](https://supabase.com/docs/guides/cron/quickstart).

`python scripts/pruebas_revisiones.py` ejecuta la suite local integral. Se probaron las fronteras antes y al cumplir 3, 5, 90 y 180 días; rechazos del evaluador y del Comité; reinicio desde el director; falta de formatos/reporte; previsualización y avisos privados; pausa de revisión; reposición de espera/vigencia/corrección; cancelación y liberación de idea; e idempotencia. `database/pruebas/pausa_calendario.sql` es una prueba reversible exclusiva del entorno local y no debe instalarse en Supabase.

Las capturas se hicieron con cuentas y proyectos ficticios de `grado-pruebas`, en el puerto 8082. El contenedor principal en el puerto 8080 utiliza Supabase y no recibió fixtures.

La fase Final ya se abre tras aprobar el informe. Sus entregables opcionales, el cierre por el Comité, las solicitudes y el historial se implementaron en el bloque siguiente; véase `CIERRE_Y_SOLICITUDES.md`. Quedan pendientes actas, mensajería y administración posterior de cuentas.
