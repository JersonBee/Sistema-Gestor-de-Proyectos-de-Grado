# Revisión funcional del sistema

Fecha: 19 de octubre de 2026, hora de Bogotá.

## Resultado

No se encontraron fallos funcionales reproducibles en los recorridos ejecutados. La suite local integral terminó correctamente. En el despliegue público se completaron 71 comprobaciones HTTP y se verificaron los siete archivos de demostración. Una conexión TLS de Secretaría falló inicialmente antes de recibir respuesta HTTP; el reintento autenticado del mismo acceso respondió 200. La incidencia original se conserva en el registro privado.

No se cambiaron cuentas, documentos ni proyectos académicos en Supabase durante esta revisión. Las pruebas que crean, revisan, pausan, retiran o finalizan proyectos se ejecutaron exclusivamente en `grado_pruebas`, el entorno Docker aislado del puerto 8082. El acceso público genera las sesiones de prueba normales del sistema.

## Pruebas locales

Comando: `python -u scripts/pruebas_completas.py`.

- Registro autoactivo de estudiantes y docentes, perfiles múltiples, validaciones y límite UTF-8.
- Autenticación, CSRF, consultas parametrizadas, rotación de sesión, cuentas inactivas y logout.
- Ideas propias/docentes, aprobación, reserva concurrente, proyecto individual o en pareja y datos de Pago.
- Asignación por modalidad, área y línea; director y evaluador diferentes.
- Cadena director/evaluador/Comité, rechazo, corrección, reenvío completo y versiones.
- Plazos de 3/5/90/180 días, días calendario, pausas, avisos internos y cancelación.
- Entregables opcionales, repositorio del director, cierre del Comité, solicitudes y retiros.
- Actas, mensajería privada, administración de cuentas y revocación de acceso.
- Matriz de cinco roles con 729 comprobaciones adicionales de vistas, acciones, CSRF y capas privadas.
- Paginación y conservación de filtros en siete listados.
- GET y POST entre dos instancias, navegación alternada, reinicio, cierre de sesión y cookies detrás de proxy HTTPS.
- Contrato MVC: 51 rutas públicas y separación de responsabilidades.

El conteo de 729 corresponde a la matriz adicional; no representa la suma de todas las aserciones de la suite.

## Comprobaciones públicas

Se autenticaron cuentas DEMO de Estudiante, Director, Evaluador, Comité y Secretaría. Se comprobaron inicio, perfil, tareas, banco, proyectos y avisos; además, resumen y detalle de los 14 proyectos identificados en el conjunto de demostración.

Se verificaron rechazos esperados a proyectos ajenos, archivos WEB-INF y administración de cuentas desde Secretaría. También se comprobó la segunda página del banco y la apertura del formulario para seleccionar una idea disponible con una cuenta libre, sin crear un proyecto nuevo.

Las consultas de solo lectura no encontraron estudiantes en dos proyectos activos, ideas reservadas por más de un proyecto, dos fases abiertas simultáneamente ni docentes ocupando ambos cargos en un mismo proyecto.

`database/supabase/03_verificar_cron.sql` pasó la verificación de solo lectura: trabajo de plazos activo, frecuencia de un minuto y ejecución reciente correcta.

## Documentos

Se verificaron las páginas `documento.jsp` para los tipos documentales existentes: respuesta autorizada, iframe y enlace alternativo. Se descargaron los bytes durante la comprobación técnica para verificar SHA-256 contra los originales; esto comprueba integridad y acceso, no renderizado visual.

| Archivo | Respuesta | Tipo servido | Alcance confirmado |
|---|---|---|---|
| F-DC-124 | 200 | application/msword | URL e integridad; Word sin previsualización inline garantizada |
| F-DC-125 | 200 | application/vnd.openxmlformats-officedocument.wordprocessingml.document | URL e integridad; Word sin previsualización inline garantizada |
| F-DC-129 | 200 | application/vnd.openxmlformats-officedocument.wordprocessingml.document | URL e integridad; Word sin previsualización inline garantizada |
| Turnitin Gardenia | 200 | image/png | URL e integridad; formato de imagen/texto compatible con navegador |
| Turnitin Gestor | 200 | image/png | URL e integridad; formato de imagen/texto compatible con navegador |
| Comprobante ficticio | 200 | text/plain | URL e integridad; formato de imagen/texto compatible con navegador |
| Nota de demostración | 200 | text/plain | URL e integridad; formato de imagen/texto compatible con navegador |

Los tres formatos institucionales continúan siendo Word; el visor apunta directamente al archivo y no hay conversión a PDF ni un servicio de renderizado Word. Por tanto, no se afirma que puedan leerse sin descarga. Las imágenes y los textos son formatos compatibles con el navegador, pero no se completó su inspección visual en esta revisión.

## Límites de la revisión

- Computer Use detuvo la inspección porque no pudo determinar con suficiente certeza la URL actual de Chrome. No se emitieron más acciones de interfaz. La pestaña del navegador del IDE tampoco expuso herramientas de inspección en esta sesión.
- Vercel MCP rechazó la consulta de errores con 403. No había CLI local disponible como alternativa. La comprobación pública se hizo mediante HTTP, sin acceso a los logs actuales ni confirmación del commit desplegado.
- Los resultados cubren los recorridos y datos probados. No constituyen una garantía de ausencia de cualquier defecto ni una validación de carga masiva.

Los detalles de rutas y de la incidencia de transporte se conservan en `.tools/demostracion/AUDITORIA_SISTEMA_20261019.json`, excluido de Git y sin contraseñas. No se subió código ni se realizó un despliegue remoto durante esta revisión.
