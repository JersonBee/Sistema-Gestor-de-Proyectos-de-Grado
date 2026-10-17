# Actas, mensajes, cuentas y búsqueda

Las rutas públicas siguen entrando por controladores JSP/JSTL. Las consultas y llamadas parametrizadas están en `WEB-INF/modelo`; las vistas no contienen SQL. Las funciones de este bloque están en `database/011_administracion_comunicacion.sql`.

## Actas

Desde el detalle del proyecto se abre **Actas**. El Comité registra número único, fecha, descripción y detalles. El registro queda pendiente y solo el Comité puede consultarlo hasta aprobarlo. La aprobación genera un aviso interno y habilita la consulta a los usuarios autorizados del proyecto, incluidos los participantes históricos. Los proyectos en pausa no admiten registros ni aprobaciones; las consultas permanecen disponibles.

El detalle muestra quién registró y aprobó el acta. El navegador permite imprimirla o guardarla como PDF; la hoja de impresión oculta navegación y botones. El contenido aprobado no tiene operaciones de edición en esta aplicación. Registrar un acta no sustituye las decisiones de revisión ni cambia automáticamente la fase del proyecto.

## Mensajes privados

**Mis mensajes** abre la correspondencia entre cada estudiante vigente y su director actual, mientras el proyecto esté activo. Se puede enviar, responder y marcar los recibidos como leídos. El estado de lectura solo lo cambia el destinatario. Cada usuario consulta únicamente los mensajes que envió o recibió; el compañero de proyecto, evaluador, Comité y Secretaría no acceden al contenido ajeno.

Tras un retiro, cambio de director o cierre se conserva la correspondencia histórica de sus participantes. La pausa impide nuevos envíos. El aviso interno del destinatario y el historial general no reproducen el contenido privado. Se muestran veinte mensajes por página.

## Administración de cuentas

**Administrar cuentas** está disponible únicamente para el Comité. Permite buscar por nombre/correo, consultar datos y cambiar el único rol y el estado de acceso. Un cambio de rol o estado revoca las sesiones anteriores; reactivar exige iniciar sesión de nuevo.

Para cambiar el rol deben resolverse primero las participaciones o asignaciones vigentes. Asignar Director/Evaluador a una cuenta sin perfil requiere áreas, líneas, modalidades, cursos, títulos y temas. Los errores no dejan un perfil parcialmente creado. El Comité no puede quitarse a sí mismo el acceso ni dejar al sistema sin una cuenta activa del Comité. Desactivar una cuenta no pausa automáticamente sus proyectos; esa operación está en el detalle del proyecto y ajusta sus plazos.

## Búsqueda de proyectos

**Proyectos** permite combinar título/número, estudiante, director, evaluador, modalidad, estado, fase y fechas de creación. Cada filtro se aplica dentro de los proyectos que el usuario está autorizado a consultar. Las búsquedas por docente incluyen asignaciones históricas. Las fechas de creación se interpretan en Bogotá y son inclusivas. La fase muestra la más reciente iniciada o de cierre. Los enlaces de paginación conservan los filtros y presentan veinte resultados por página.

## Verificación

`python scripts/pruebas_comunicacion.py` instala y prueba este bloque en `grado-pruebas`, PostgreSQL local aislado, y ejecuta además los flujos anteriores. No utiliza la conexión de Supabase. Incluye pruebas de privacidad, autorización, CSRF, aprobación duplicada, pausa, filtros individuales/combinados, cambios de rol, revocación de sesiones y correspondencia histórica.
