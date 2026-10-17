# Resultado de pruebas funcionales y permisos

Fecha: 17 de octubre de 2026, hora de Bogotá.

**Resultado final: pruebas ejecutadas sin fallos después de corregir un defecto de registro docente.** Primero se ejecutaron la suite integral `pruebas_tareas.py` y la matriz ampliada `pruebas_permisos_roles.py`. Tras encontrar y corregir el defecto se repitió el recorrido completo mediante `pruebas_completas.py`, incluidos los casos nuevos de registro, y se ejecutó adicionalmente `pruebas_paginacion.py`. La matriz completó **729 comprobaciones adicionales**; el número no incluye los escenarios y aserciones de las suites de negocio, registro y paginación.

## Entornos

- Flujos de negocio y permisos: PostgreSQL local `grado_pruebas`, servicio `bd_pruebas`, aplicación en el puerto 8082, con cuentas y proyectos ficticios.
- Servicio principal: comprobación del WAR, restricciones de vistas, salud JSTL y entrada al login en localhost:8080.
- Supabase Cron: la comprobación de solo lectura `03_verificar_cron.sql` confirmó el trabajo único activo, su frecuencia de un minuto y una ejecución correcta en los últimos cinco minutos.
- Contrato MVC: 51 rutas públicas y separación de modelo, controlador y vistas.
- No se crearon ni modificaron usuarios, proyectos o documentos académicos de Supabase durante estas pruebas.

## Defecto encontrado y corregido

El registro docente aceptaba listas de áreas o líneas compuestas solo por comas y espacios, creando un perfil sin esas asociaciones. Se reprodujo mediante una transacción local reversible. La migración `012_validacion_perfil_docente.sql` exige al menos un valor real en ambas listas, antes de insertar la cuenta. Se repitió la suite completa y se probaron listas vacías, campos obligatorios, modalidades inválidas, roles restringidos, contraseñas no coincidentes, duplicados y un registro válido de Evaluador con múltiples áreas, líneas y modalidades.

La corrección se aplicó también a Supabase; una comprobación de solo lectura confirmó su instalación. No se modificaron perfiles existentes. La primera ejecución del aplicador no finalizó correctamente y el reintento devolvió `SQL_APLICADO_OK`; la verificación posterior confirmó el estado instalado.

## Cobertura por rol

| Rol | Operaciones verificadas |
| --- | --- |
| Estudiante | Registro autoactivo, acceso, propuestas de ideas, selección/reserva, proyecto individual/pareja, Pago, entregas completas, corrección/reenvío, solicitudes y retiro, adicionales de Final, mensajes y avisos propios, consulta vigente/histórica. |
| Director | Registro/perfil docente, aptitud para ideas, propuesta de ideas, revisión del conjunto asignado, reporte obligatorio, aprobación/rechazo, mensajes privados, repositorio de Final y consulta histórica. |
| Evaluador | Acceso y perfil, revisión después del director, aprobación/rechazo con reporte, bloqueo al omitir etapas, asignación por aptitud, cambio de evaluador y consulta histórica. |
| Comité | Decisiones de ideas/Pago/revisiones, asignación posterior a Pago, solicitudes/cambios/retiros, pausa/reanudación, actas/aprobación, cierre exclusivo, administración de cuentas/rol/estado y revocación de sesiones, búsqueda e historial. |
| Secretaría | Consulta de proyectos, resumen, docentes, fases, documentos, versiones, solicitudes, actas aprobadas e historial; acceso bloqueado a decisiones, entregas, administración y contenido privado ajeno. |

## Reglas y escenarios comprobados

- Un rol por usuario y autorregistro restringido a estudiante/docente; no se admite autorregistro del Comité.
- Contraseñas con hash, autenticación, rotación de sesión, cierre y bloqueo de cuentas inactivas.
- Ideas pendientes/aprobadas, docentes aptos por las tres coincidencias y reserva concurrente de una idea.
- Un solo proyecto vigente por estudiante; participantes individuales o en pareja y datos presentados en Pago.
- Comprobante y conjunto documental versionado; rechazo de decisiones sobre entregas antiguas.
- Cadena estudiante → director → evaluador → Comité, reporte obligatorio y reinicio por rechazo o vencimiento.
- Corrección de tres días con alerta y reenvío permitido; revisión de cinco días sin autoaprobación.
- Espera de 90 días, vigencia de 180, cancelación/liberación, idempotencia y ajuste de plazos por pausa.
- Adicionales opcionales, repositorio por director y cierre del Comité sin exigir adicionales.
- Cambio de docente con traslado de revisión, retiro en pareja/individual y cierre de solicitudes al terminar el proyecto.
- Actas pendientes privadas, aprobación y consulta autorizada; aprobación repetida sin duplicar efectos.
- Mensajes visibles solo para remitente/destinatario, lectura solo por destinatario y bloqueo de envío tras retiro/cierre.
- Filtros individuales/combinados, escape de contenido, paginación de las vistas y fechas inválidas controladas.
- Segunda página y retorno de ideas, tareas, proyectos, cuentas, mensajes, avisos e historial. Para comprobar límites y conservación de filtros se crearon más de veinte registros ficticios a través de los flujos HTTP locales; donde se verificó el contenido, la primera página mostró veinte y la segunda el registro restante sin duplicación.
- Resumen y tareas durante las transiciones; ausencia de tareas ajenas, de proyectos pausados y de cierres ya resueltos.
- Inicio directo en login, formularios de registro y tarjetas autorizadas para los cinco roles.
- Director/evaluador vigentes, última asignación en proyectos cerrados y «Por asignar» cuando corresponde.
- Pop-ups emitidos solo para fases iniciadas; consultas de proyectos activos, cancelados y en Final.

## Matriz ampliada

La matriz recorre las vistas privadas con los cinco roles y compara las respuestas permitidas/prohibidas. Revisa todas las acciones protegidas declaradas en `acciones/`, bloquea GET y CSRF incorrecto, intenta acciones de roles ajenos, verifica accesos sin sesión y comprueba HTTP 404 para cada archivo JSP dentro de `WEB-INF`. También contrasta el inventario de acciones con los archivos reales para detectar futuras omisiones.

Los detalles de las 729 comprobaciones están en `.tools/resultado-pruebas-permisos.json`, excluido del repositorio y sin contraseñas ni tokens.

## Repetir la verificación

```powershell
python -u scripts/pruebas_completas.py
.\scripts\verificar.ps1
```

El primer comando reconstruye los fixtures de la base local de pruebas. No utiliza `.env` ni se conecta a Supabase. La comprobación PowerShell sí consulta la entrada pública del contenedor principal, cuyo formulario puede utilizar su conexión JNDI; no registra ni modifica datos académicos.

## Alcance del resultado

No se detectaron errores en los escenarios ejecutados. Esto verifica los flujos implementados y sus controles de acceso; no constituye una garantía para todas las combinaciones posibles de datos. La disponibilidad de enlaces externos y la visualización de documentos dependen de sus proveedores. El despliegue remoto y las pruebas de carga no forman parte de esta ejecución.
