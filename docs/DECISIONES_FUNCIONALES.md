# Aclaraciones del alcance — 16 de octubre de 2026

Fuente: respuestas expresas del usuario en esta conversación. Se completó la lectura visual de las 14 páginas del PDF original para interpretar el contexto y resolver dudas, por solicitud posterior del usuario. Esa lectura no reincorpora automáticamente requisitos excluidos del sistema simplificado. Las rondas se conservan cronológicamente; la más reciente prevalece sobre las anteriores y sobre el SDD inicial.

| Nº | Decisión confirmada | Efecto |
| --- | --- | --- |
| 1 | Un solo rol por usuario. | `usuario.rol_codigo` único por cuenta. |
| 2 | Director y evaluador distintos; estudiante en un solo proyecto. | Una participación vigente por estudiante y una sola función vigente de cada docente dentro de un proyecto. |
| 3 | El Comité aprueba las ideas propias; elegir una idea la reserva al proyecto. | Se exige aprobación al crear el proyecto y se impide asociar la idea a otro proyecto. |
| 4 | Aptitud por coincidencia de modalidad, área y línea. | Catálogos compartidos y vista de coincidencia conjunta. |
| 5 | Propuesta II e Informe II contienen la continuación de evaluación hasta el Comité. | I: entrega al director; II: evaluador → Comité, usando el mismo conjunto de documentos. |
| 6 | El comprobante pasa por aprobación y el Comité aprueba el conjunto. | Entregas con versiones concretas y decisiones sobre el conjunto. |
| 7 | Reporte en texto; rechazo reinicia desde estudiante → director. | Se conserva reporte escrito y una nueva entrega para la corrección. |
| 8 | Todo día cuenta. | Los plazos son calendario, incluidos fines de semana y festivos. |
| 9 | Vencimiento de revisión devuelve la acción al estudiante. | `aplicado` termina el ciclo; no aprueba automáticamente ni pasa al evaluador/Comité. |
| 10 | Tras 3 días se alerta, pero se permite reenviar. | Sustituye el bloqueo de RF-22 CA2 y su interpretación inicial. |
| 11 | Inicio de Informe I inicia el reloj; entrega después de 90 días y cancelación al pasar 180. | Reemplaza el inicio de espera de RN-06/RF-24 y concreta RN-07/RF-25. El reloj no reinicia con correcciones. |
| 12 | Se acepta cualquier enlace. | Sin comprobación de extensiones `.docx`/`.pdf`; sustituye RN-08/RF-15. Se admiten enlaces web sin extensión. |
| 13 | El Comité aprueba cambios y retiros; ve todo el historial. El estudiante ve los cambios de su propio proyecto. | Alcance del acceso y responsable de decisiones definido. |
| 14 | Solo JSTL, sin servlets, DAOs ni scriptlets. | Se conserva la restricción; aún no se fija cómo acceder de forma segura a PostgreSQL. |
| 15 | Sin correo; avisos de vencimiento dentro del sistema. | RF-20 cambia de canal; se eliminan datos de envío de correos. Los eventos ya previstos de documentos/solicitudes usan también avisos internos. |

## Interpretación de las fases

Se revisaron visualmente las páginas 1 y 2 de `C:\Users\inteligencia\Downloads\Requerimiento.pdf`, que enumeran las seis fases. El PDF es escaneado y sus notas son manuscritas.

1. Pago: comprobante, idea aprobada, título, objetivos, descripción y director preferido.
2. Propuesta I: F-DC-124 y Turnitin para revisión del director.
3. Propuesta II: después del director, pasa al evaluador y luego al Comité.
4. Informe I: F-DC-125, F-DC-129 y Turnitin para revisión del director. La espera y vigencia se toman de la respuesta más reciente del usuario.
5. Informe II: después del director, pasa al evaluador y luego al Comité.
6. Final: posterior a la aprobación del informe por el Comité; se conservan los entregables finales del SDD simplificado.

Las menciones del PDF a firmas se representan mediante las decisiones de aprobación existentes; no se incorpora firma electrónica. Tampoco se agregan agendamiento de sustentaciones, prórrogas, TyT, porcentajes de similitud, límites de archivos o requisitos de otros apartados de las entrevistas.

## Segunda ronda de decisiones

| Nº | Decisión confirmada | Efecto |
| --- | --- | --- |
| 1 | VS Code, Supabase, GitHub, Vercel y pruebas en Tomcat de XAMPP. | Se conserva PostgreSQL; validar la integración y el despliegue de Tomcat. |
| 2 | Informe I comienza al aprobar el Comité Propuesta II. | Transición e inicio de los 90/180 días en la misma operación. |
| 3 | Aprobación del informe por el Comité permite avanzar sin los adicionales. | `informe_aprobado_comite_en` detiene la cancelación por plazo; los adicionales son opcionales y admiten URL. |
| 4 | Los estados cambian sin usuarios conectados. | Se requiere ejecución programada; Supabase Cron implementado y verificado con ejecución cada minuto. |
| 5 | Por demora del docente se permite reenviar los mismos enlaces. | Nuevo registro de entrega y ciclo, conservando el historial. |
| 6 | Toda corrección presenta nuevamente el conjunto completo. | No se acepta enviar solo el enlace del documento corregido. |
| 7 | Cancelar o retirar a todos devuelve la idea al banco. | Reserva por índice parcial para proyectos no cancelados, sin borrar asociaciones históricas. |
| 8 | Retiro aprobado del único integrante cancela el proyecto. | Cierre de participación, cancelación, liberación de idea y avisos en una transacción. |
| 9 | Director y evaluador ven el historial de sus proyectos; Secretaría también puede consultar. | Se amplía el acceso de lectura, sin conceder modificación. |
| 10 | Si no es posible previsualizar, abrir el enlace en otra pestaña. | Alternativa de consulta aceptada por el usuario. |
| 11 | Varias áreas y líneas por docente. | Relaciones `docente_area` y `docente_linea`; se mantiene coincidencia conjunta para aptitud. |

Esta ronda sustituye las interpretaciones anteriores que suponían reserva permanente, una sola área por docente o falta de acceso de otros roles al historial.

## Tercera ronda de decisiones

| Nº | Decisión confirmada | Efecto |
| --- | --- | --- |
| 1 | Pago e idea se aprueban por el Comité; los docentes se asignan después. | Pago queda exento de la cadena docente; aprobación registrada en `datos_pago` y comprobada antes de asignar. |
| 2 | Manual, licencia y evidencia son opcionales, según solicitud de docentes/Comité. | Se elimina la obligatoriedad de RN-11/RF-36, incluido software. Se mantienen sus espacios de registro. |
| 3 | Modalidades: Monografía, Emprendimiento, Proyecto de investigación y Desarrollo de software. | Se siembran cuatro modalidades; no se crea una quinta. El PDF usa también la expresión Desarrollo tecnológico; se conserva el nombre software indicado en el alcance actual. |
| 4 | Los integrantes se especifican con datos personales en Pago. | FK a cuenta más datos presentados de nombre, documento, correo y teléfono. No se agrega un flujo de invitaciones. |
| 5 | El docente se registra con formulario propio y su aprobación es automática en el aula. | Trigger de autoactivación solo para cuentas Director/Evaluador. No se extiende silenciosamente a Comité, Secretaría o registro estudiantil. |
| 6 | Plazos al cierre del último día, 23:59. | Zona America/Bogota; el evento es día cero; función SQL de límite calendario. No se confirmó frecuencia exacta de Cron, por lo que no se registra una frecuencia como aprobada. |
| 7 | Desactivar pausa todos los procedimientos del proyecto. | Historial de pausas; exclusión de procesamiento y trámites mientras esté desactivado; ajuste de fechas al reanudar. |
| 8 | Se admite JSTL, incluidas sus etiquetas SQL, sin servlet, DAO o scriptlet. | Vía de acceso prevista: JSTL SQL mediante JDBC hacia PostgreSQL de Supabase. |
| 9 | Hashes generados/verificados en PostgreSQL. | Utilidades con pgcrypto; no guardar contraseñas en texto plano. |
| 10 | Las dependencias deben estar dentro del proyecto y empaquetarse con Docker para Vercel. | Dependencias versionadas y empaquetadas en WAR/imagen al implementar la aplicación; no depender de instalaciones manuales de bibliotecas en el equipo. |
| 11 | Proyecto Supabase ya existente; repositorio GitHub después. | No crear otra base/proyecto ni publicar un repositorio todavía. |

La frecuencia de ejecución programada y el ajuste preciso de plazos al reanudar son detalles técnicos que se concretarán al implementar y probar las operaciones.

## Confirmación final de registro y cierre

- Solo el Comité marca un proyecto como finalizado. Se conserva su responsable y fecha de cierre.
- Tanto estudiantes como docentes se activan automáticamente al registrarse. Esta respuesta sustituye las interpretaciones previas que limitaban la autoactivación a docentes, y modifica RN-13 y el flujo inicial de RF-01/RF-02.
- Se conserva la administración posterior de cuentas por el Comité. La autoactivación de registros no autoriza el autorregistro con roles de Comité o Secretaría ni reactiva cuentas previamente deshabilitadas.

## Precisiones de implementación aún abiertas

El entorno base de la aplicación se concretó después de estas rondas: Java 21, Tomcat 11.0.27, Maven Wrapper 3.9.16, API JSTL 3.0.2, implementación 3.0.1 y JDBC PostgreSQL 42.7.14. Las imágenes se fijaron por digest y se añadió configuración Docker, pool JNDI y variables externas. La paleta usa blanco, gris y el verde predominante del logo proporcionado (`#C7D309`). Esto prepara el entorno; no declara implementadas las operaciones funcionales. Véanse `README.md` y `docs/VALIDACION_ENTORNO.md`.

- La conexión JSTL SQL/JDBC, los hashes pgcrypto y los módulos de acceso, ideas, Pago y revisiones están implementados y probados. Se usa Session Pooler con TLS verify-full. Por decisión del usuario, se conserva la cuenta de conexión proporcionada para el trabajo de aula.
- Supabase Cron ya ejecuta `grado.procesar_plazos()` cada minuto mediante el trabajo `grado-procesar-plazos`. Se verificó una ejecución real correcta y se probaron las transacciones e idempotencia en PostgreSQL aislado. Véase `REVISIONES_Y_PLAZOS.md`.
- Vercel ofrece despliegue de contenedores; validar Tomcat/JSP/JSTL, recursos y sesiones en ese entorno antes de confirmar el despliegue. No se ha publicado nada.
- Cualquier enlace web puede registrarse; si no puede embeberse, se permite abrirlo en otra pestaña.
- La vigencia se aplica a proyectos en curso. El cierre debe terminar las participaciones vigentes sin borrar su historial; no se supone una prohibición de cursar otro proyecto en el futuro.
- La cancelación libera la idea; finalizar un proyecto no la libera porque esa reutilización no se ha solicitado.
