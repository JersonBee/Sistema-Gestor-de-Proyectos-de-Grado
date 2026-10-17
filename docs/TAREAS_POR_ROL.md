# Bandeja de tareas

**Mis tareas** reúne las acciones disponibles para la cuenta conectada. El inicio presenta hasta seis; la bandeja completa muestra veinte por página y prioriza revisiones con fecha límite, luego antigüedad. Cada entrada abre la pantalla correspondiente, donde se vuelven a comprobar permisos, estado y CSRF antes de cualquier decisión.

| Cuenta | Tareas |
| --- | --- |
| Estudiante | Presentar o reenviar Pago, Propuesta I e Informe I cuando corresponde; leer mensajes propios recibidos. |
| Director / Evaluador | Revisar el conjunto que tenga asignado en el ciclo vigente; leer mensajes propios recibidos. |
| Comité | Decidir ideas, revisar Pago/Propuesta/Informe, asignar docentes tras Pago aprobado, atender solicitudes, aprobar actas y revisar el cierre en Final. |
| Secretaría | Consulta de proyectos; no recibe tareas de decisión. |

La bandeja no marca una entrega mientras el conjunto esté en revisión ni antes de habilitar Informe I. Los adicionales de Final no se convierten en obligaciones del estudiante. Los proyectos pausados no generan tareas de entrega, revisión o solicitudes; tampoco aparece un cierre para proyectos ya cerrados. Las actas vinculadas a un proyecto en pausa esperan su reanudación.

La consulta histórica y la lectura de mensajes recibidos siguen disponibles durante una pausa o tras el cierre cuando el usuario conserva acceso. Los mensajes sin leer se agrupan por proyecto y la bandeja muestra únicamente su cantidad, sin contenido privado. Al marcarlos como leídos desaparece esa tarea.

Los plazos alcanzados pueden permanecer visibles hasta la siguiente ejecución de Cron. La bandeja lo indica y no ejecuta transiciones por abrir una página. Las reglas y funciones de escritura siguen siendo las mismas: esta mejora no cambia tiempos ni etapas.

El controlador JSP/JSTL usa una consulta parametrizada en `WEB-INF/modelo/tareas/lista.jsp`. No requiere migración ni cambios en Supabase. `python scripts/pruebas_tareas.py` prueba la bandeja durante los flujos completos en PostgreSQL local aislado, incluidas autorización, cambios de etapa, rechazo, espera, pausa, actas, mensajes y cierre.
