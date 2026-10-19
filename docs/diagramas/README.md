# Diagramas del sistema

## Arquitectura

[Imagen PNG](ARQUITECTURA.png) · [SVG ampliable](ARQUITECTURA.svg) · [Fuente Graphviz](ARQUITECTURA.dot).

Representa la arquitectura del repositorio: navegador, router de Vercel, contenedor Java/Tomcat, controladores JSP, vistas, modelo JSTL SQL, pool JNDI, sesiones nativas y servicios de Supabase. Las líneas de construcción/despliegue se distinguen del flujo de ejecución. No muestra las migraciones como un paso automático del despliegue.

Las consultas JDBC utilizan el Session pooler configurado. Los documentos se consultan por URL desde el navegador. Cron procesa los plazos en PostgreSQL independientemente de las sesiones de usuario. El esquema usa autenticación propia; no Supabase Auth.

## Secuencia de presentación y revisión de documentos

[Imagen PNG](SECUENCIA_DOCUMENTOS.png) · [SVG ampliable](SECUENCIA_DOCUMENTOS.svg).

Representa cinco participantes: usuario/navegador, controlador, vista, modelo de acceso y PostgreSQL. Incluye presentación, POST/Redirect/GET, validación de sesión/CSRF/contexto, registro atómico de documentos y revisión por director, evaluador y Comité. El fragmento alternativo distingue aprobación académica de rechazo y reenvío completo.

Se basa en `documentos-enviar.jsp`, `revision-decidir.jsp`, sus modelos y las funciones `grado.presentar_documentos` / `grado.decidir_revision`. Pago es una excepción: lo revisa directamente el Comité. Las comprobaciones del GET se agrupan como consulta autorizada, sin repetir todos los detalles de sesión.

La fuente reproducible está en `scripts/generar_secuencia_documentos.py`. Utiliza Pillow para el PNG y genera un SVG equivalente; no añade dependencias a la aplicación.

## Modelo entidad–relación

Generado el 19 de octubre de 2026 a partir de los metadatos del esquema `grado` de Supabase. No contiene registros de usuarios, contraseñas ni credenciales de conexión.

| Archivo | Contenido |
|---|---|
| [MER_completo.png](MER_completo.png) | Imagen completa: 37 tablas, 212 campos y 66 claves foráneas. |
| [MER_completo.svg](MER_completo.svg) | Mismo diagrama en formato vectorial, recomendado para ampliar e imprimir. |
| [MER_general.png](MER_general.png) | Vista resumida: 20 tablas principales y 22 relaciones estructurales. |
| [MER_general.svg](MER_general.svg) | Vista general ampliable. |
| `MER_completo.dot` / `MER_general.dot` | Fuentes editables de Graphviz. |
| `esquema_mer.json` | Metadatos de tablas, columnas, restricciones e índices utilizados. |

## Lectura y alcance

- **PK**: clave primaria; **FK**: clave foránea; **NULL**: campo que admite ausencia de valor.
- **1**: exactamente uno; **0..1**: relación opcional con uno; **0..N**: cero o varios.
- Las líneas del completo identifican las columnas de la FK. Una FK compuesta se representa con una sola línea que agrupa sus columnas.
- Las cardinalidades corresponden al modelo físico y su historial. No sustituyen las restricciones de negocio sobre registros vigentes.
- La vista general omite tablas auxiliares y relaciones de autoría para facilitar la exposición. El diagrama completo es la referencia para la totalidad del esquema.

## Restricciones de vigencia que complementan el dibujo

Una idea puede tener varios proyectos históricos cancelados, pero solo uno no cancelado la reserva. Un proyecto finalizado conserva su reserva. Por eso el vínculo histórico idea–proyecto aparece como uno a muchos.

Un estudiante tiene una sola participación vigente; un proyecto admite dos plazas vigentes. Un proyecto conserva asignaciones históricas, pero solo un director y un evaluador vigentes, distintos entre sí. Las relaciones históricas se dibujan como uno a muchos aunque los índices parciales limiten los registros vigentes.

Cada cuenta tiene un único rol mediante `usuario.rol_codigo`. Las tablas puente docentes permiten varias áreas, modalidades y líneas. La vista `docente_apto_idea` calcula la coincidencia de esos tres criterios; no es una tabla y no aparece entre las 37 entidades físicas.

`sesion_http` e `intento_acceso` no tienen una FK hacia `usuario`: no se inventaron relaciones para conectarlas al diagrama. `sesion_acceso` sí tiene esa relación.

Las condiciones UNIQUE, CHECK y los índices parciales completos se explican en la [documentación del sistema](../../DOCUMENTACION_Y_GUION_DEL_SISTEMA.md).

## Regeneración

`python scripts/generar_mer.py` genera las fuentes `.dot` desde el archivo de metadatos. Con Graphviz instalado, ejecutar `dot -Tpng archivo.dot -o archivo.png` o `dot -Tsvg archivo.dot -o archivo.svg`. Las herramientas de generación no son dependencias de ejecución de la aplicación.
