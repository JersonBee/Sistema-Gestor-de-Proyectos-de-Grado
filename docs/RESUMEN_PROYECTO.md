# Resumen del proyecto

La opción **Ver resumen y siguiente paso** del detalle abre `/resumen.jsp?id=…`. Atiende RF-38: fase, responsable, documentos pendientes, fechas límite y estado general en una sola vista.

| Situación | Indicación del resumen |
| --- | --- |
| Pago sin entrega | Estudiantes: presentar comprobante y adicionales solicitados. |
| Pago en revisión | Comité: revisar el conjunto presentado. |
| Pago aprobado sin asignación | Comité: asignar director y evaluador. |
| Propuesta o Informe por presentar | Estudiantes: presentar el conjunto completo al director. |
| Conjunto en revisión | Nombre del responsable o Comité; plazo de cinco días solo cuando corresponde. |
| Rechazo o vencimiento de revisión | Estudiantes: corregir y reenviar todo al director; límite de corrección y recordatorio de que el vencimiento solo alerta. |
| Espera de Informe I | Preparar el conjunto; mostrar habilitación a los 90 días y vigencia hasta los 180. |
| Informe II aprobado / Final | Comité: finalizar; adicionales opcionales y cancelación por vigencia detenida. |
| Proyecto pausado | Comité: reanudar; plazos suspendidos, sin mostrar límites como si siguieran corriendo. |
| Proyecto finalizado o cancelado | Proceso cerrado, consulta del historial y sin plazos activos. |

El enlace del siguiente paso dirige a Pago, Propuesta, Informe, Final o Historial según el estado. No ejecuta decisiones ni avanza fases. Si hay solicitudes pendientes, ofrece el acceso a su listado sin reproducir su contenido.

El modelo es una consulta parametrizada con las funciones de autorización existentes; no modifica datos ni requiere migración. El controlador prepara las indicaciones y la vista las presenta escapadas. Los mismos permisos de consulta del proyecto protegen el resumen, incluidos los accesos históricos.

`python scripts/pruebas_resumen.py` ejecuta las suites anteriores y verifica el resumen durante las transiciones reales del flujo en PostgreSQL local aislado. Las comprobaciones también quedan integradas en las pruebas de Pago, revisiones, comunicación y cierre.
