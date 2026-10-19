# Revisión adicional de código — 19 de octubre de 2026

## Error reproducido

Los formularios de Pago y propuesta/informe permiten introducir enlaces adicionales, uno por línea. Un textarea HTML puede enviar esas líneas con CRLF (`\r\n`). Las funciones SQL separaban únicamente por LF y `btrim(x)` no eliminaba el carácter CR restante. El validador HTTP/HTTPS interpretaba ese carácter como un espacio interno y rechazaba enlaces válidos.

Se reprodujo mediante un POST real al formulario de Pago del entorno Docker aislado: con dos enlaces, líneas vacías y salto final CRLF, la entrega no se creaba y fallaba la aserción de envío correcto. El recorrido anterior con LF ya estaba cubierto, pero no reproducía el formato de envío del navegador.

## Corrección

- `database/007_ideas_pago.sql`: separación de líneas CRLF, LF o CR al presentar Pago.
- `database/008_revisiones_plazos.sql`: misma corrección al presentar propuesta o informe.
- En ambos casos se omiten líneas vacías y se recortan espacios/tabulaciones exteriores, conservando la validación de URL. No se eliminan espacios internos para convertir una URL inválida en una válida.
- `database/014_enlaces_adicionales_multilinea.sql`: actualización aditiva de las dos funciones para bases instaladas; conserva sus firmas, permisos y datos.
- Los tests HTTP de Pago y propuesta/informe incluyen CRLF y verifican los enlaces efectivamente almacenados. Pago mantiene también un reenvío con LF para comprobar compatibilidad.

## Validación

La suite `python -u scripts/pruebas_completas.py` terminó correctamente después de la corrección:

- Envío real HTTP con CRLF y líneas vacías en Pago, propuesta e informe; los enlaces de Pago y Propuesta se contrastaron con los almacenados.
- Flujo completo, rechazos, reenvíos, documentos versionados y plazos de 3/5/90/180 días.
- Cierre, solicitudes, cambios de docentes, retiros y pausas.
- Matriz de cinco roles: 729 comprobaciones adicionales de permisos y protecciones.
- Registro, siete listados paginados y sesión entre dos instancias, reinicio y logout.
- `python scripts/verificar_mvc.py`: 51 rutas y separación de capas correctas.
- `git diff --check`: sin errores de espacios.

Durante la preparación de la regresión, una aserción incluía por error los anexos de Pago al contar los de Propuesta. Se acotó a la fase correspondiente y se repitió la suite completa, que pasó. No se confundió ese fallo de prueba con un segundo defecto de aplicación.

## Aplicación

La migración 014 se aplicó y comprobó en la base local aislada durante la suite. **Se aplicó a Supabase el 19 de octubre de 2026, con autorización del usuario.** Se verificaron las definiciones de ambas funciones y la conservación de firmas, propietario y permisos. Una comprobación SQL confirmó la normalización de dos URLs con CRLF y líneas vacías, sin crear entregas ni modificar proyectos de demostración. La presencia de la migración en Git no la ejecuta en Supabase. No es necesario reinstalar el esquema ni recrear cuentas/proyectos. La guía de despliegue incluye el orden actualizado de instalación y la migración 014 para bases existentes.

No se realizó un despliegue en Vercel ni se subieron commits como parte de esta revisión.


## Segunda revisión: paginación con fechas empatadas

Se reprodujo un defecto distinto en `WEB-INF/modelo/ideas/ideas.jsp`: el banco ordenaba únicamente por `creado_en DESC`. Cuando varias filas tienen la misma fecha, PostgreSQL puede elegir un orden distinto para los diferentes LIMIT/OFFSET. Con 85 ideas creadas en una sola operación se observaron IDs repetidos al recorrer cinco páginas y, por tanto, otros IDs omitidos. El caso menor de 41 filas no manifestó el defecto en el plan de ejecución utilizado; se conservó el caso de 85 que sí lo reprodujo.

La consulta ahora ordena por `creado_en DESC, id DESC`. El identificador único resuelve empates sin cambiar permisos, filtros ni el tamaño de página. Esto estabiliza filas con la misma fecha; la paginación por OFFSET todavía puede desplazarse si otros usuarios insertan o eliminan registros entre consultas, lo cual no se presenta como solucionado por este cambio.

Validación específica realizada después de reconstruir el contenedor aislado:

- `python -u scripts/pruebas_paginacion_empates.py`: 85 ideas con fecha idéntica, cinco páginas, sin duplicados ni omisiones.
- La prueba usa únicamente `grado_pruebas`, inicia sesión por HTTP, filtra las ideas de su cuenta y elimina sus fixtures al terminar.
- Se integró esta prueba en `scripts/pruebas_completas.py` para próximas ejecuciones. No se volvió a ejecutar toda la suite integral en esta segunda revisión; la validación fue específica del cambio.
- `python scripts/verificar_mvc.py`: 51 rutas correctas.
- `git diff --check`: sin errores de espacios.

No requiere migración SQL ni cambios de datos en Supabase. El cambio de JSP requiere subir el código y generar un nuevo despliegue para que llegue a Vercel; no se realizó ese despliegue ni un push en esta revisión.


## Tercera revisión: Pago enviado sin responsable visible

Se reprodujo mediante HTTP un fallo de coordinación de pantallas: después de presentar Pago, el resumen seguía indicando al estudiante que debía presentar el conjunto y el Comité no recibía la tarea de revisión en su bandeja. La entrega y el aviso sí existían; la pantalla de Pago permitía al Comité decidir abriéndola directamente.

Causa: las consultas de pendientes partían de `revision_entrega`, pero Pago crea primero una entrega y un ciclo abierto. Su fila de revisión se registra al decidir, a diferencia de propuesta/informe. Por ello, antes de la decisión esas consultas no encontraban el pendiente.

Corrección: las consultas de Resumen y Mis tareas parten del ciclo y su entrega, admitiendo en Pago un ciclo abierto sin fila de revisión como pendiente del Comité. En las demás fases se sigue exigiendo una revisión pendiente real. No se insertan revisiones ficticias ni se cambia la cadena de negocio.

La regresión comprueba por HTTP que, después del envío, el resumen indique Comité y conjunto en revisión, la tarea aparezca al Comité y desaparezca la tarea de envío del estudiante. También comprueba que, tras un rechazo, la tarea vuelva al estudiante y se retire la revisión del Comité.

Validación integral de esta tercera revisión: `python -u scripts/pruebas_completas.py` terminó correctamente. Incluyó la regresión del Pago enviado y rechazado, flujos completos, plazos, 729 comprobaciones adicionales de permisos, siete listados paginados, las 85 ideas con fecha idéntica y sesiones entre dos instancias. La comprobación MVC de 51 rutas y `git diff --check` también pasaron.

No requiere migración ni cambios en Supabase; las consultas JSP actualizadas requieren despliegue. No se ha realizado push ni despliegue remoto en esta revisión.


## Cuarta revisión: decisiones con proyecto o recorrido incoherente

Se reprodujeron dos POST inconsistentes mediante un usuario del Comité autorizado: enviar `id` del proyecto A junto con `solicitud` o `revision` del proyecto B. Los controladores validaban los formatos de ambos identificadores, pero no comprobaban su relación. La función resolvía el trámite de B y la respuesta redirigía a la pantalla de A.

No se demostró que un estudiante pudiera obtener permisos del Comité ni que un docente pudiera aprobar proyectos no asignados: las funciones mantenían sus controles de actor. El defecto era permitir una decisión sobre un recurso diferente del contexto declarado en el formulario, que podía ocultar dónde se aplicó el cambio.

Corrección:

- Modelos `acciones/revision-decidir/contexto.jsp` y `acciones/solicitud-decidir/contexto.jsp`: consultas parametrizadas que comprueban pertenencia al proyecto antes de decidir.
- El controlador de revisión también exige que el origen de la entrega coincida con `tipo=propuesta` o `tipo=informe`.
- Si el contexto no coincide, el controlador redirige a la respuesta 403 sin invocar la función de decisión. Las funciones conservan sus comprobaciones de sesión, rol, responsable y estado.
- No se modificaron datos, firmas de funciones ni restricciones SQL para esta corrección.

Validación: la prueba `python -u scripts/pruebas_contexto_acciones.py` falló antes del cambio porque ambas decisiones cruzadas modificaron B. Después de reconstruir el contenedor pasó: respuestas 403 y datos sin cambios para contextos incorrectos; las dos decisiones válidas devolvieron éxito y su resultado se comprobó en PostgreSQL. Se añadieron los casos a la suite integral para futuras ejecuciones.

El verificador MVC de 51 rutas pasó. La matriz adicional de permisos terminó correctamente para los cinco roles: 731 comprobaciones en los fixtures disponibles de este turno. El conteo puede variar según los casos existentes. No se volvió a ejecutar toda la suite integral en este turno.

No requiere migración en Supabase. Para que llegue al aplicativo público es necesario desplegar las JSP actualizadas; no se realizó push ni despliegue remoto.


## Quinta revisión: nombres y perfiles formados por caracteres en blanco

Se reprodujeron por HTTP dos defectos de la misma validación: el registro aceptaba un nombre con dos tabulaciones y Administrar cuentas permitía asignar Director a una cuenta con el campo obligatorio Cursos compuesto solo por tabulaciones/saltos de línea. `btrim` sin segundo argumento elimina espacios normales, pero no esos caracteres. En listas mixtas, un área válida acompañada de una entrada de tabulaciones también podía crear una entrada de catálogo sin contenido visible.

La corrección normaliza únicamente los extremos de los textos con la clase SQL `[[:space:]]`, comprueba los campos obligatorios después de esa normalización y omite elementos de lista que quedan vacíos. Conserva los espacios internos, las contraseñas y la autoactivación de estudiantes y docentes.

Se actualizaron las definiciones de registro y administración y se preparó `database/015_validacion_espacios_perfil.sql` para las bases existentes. No se modifican ni limpian automáticamente cuentas o catálogos históricos.

Las pruebas específicas ya pasaron: nombre/cursos/títulos/temas vacíos rechazados, perfil de registro válido con listas mixtas sin entradas adicionales, cinco campos administrativos vacíos rechazados sin crear perfil parcial, y promoción válida con dos áreas y una línea. Se integró la comprobación administrativa nueva en la suite completa.

La suite integral terminó correctamente, incluyendo registro, administración, flujos académicos, 731 comprobaciones adicionales de permisos, siete listados, 85 ideas con fecha idéntica, contexto de decisiones y sesiones entre instancias. El conteo de permisos depende de los fixtures disponibles.

La migración 015 se aplicó en Supabase el 19 de octubre de 2026. Se verificaron las definiciones y la conservación de firmas, propietarios y permisos. Una llamada de registro con nombre de tabulaciones devolvió `ok=false` dentro de una transacción revertida, sin crear cuentas persistentes. No se limpiaron ni modificaron cuentas existentes. La corrección SQL queda activa sin redesplegar; las correcciones JSP de revisiones anteriores todavía requieren subir y desplegar el código. No se realizó push ni despliegue remoto.


## Sexta revisión: límites de acceso y expiración

No se confirmó un defecto nuevo en los casos revisados. Se añadió y ejecutó `python -u scripts/pruebas_limites_acceso.py` contra una cuenta temporal de `grado_pruebas`, comprobando por HTTP y PostgreSQL:

- Diez contraseñas incorrectas generan diez intentos y no crean una sesión.
- Alternar mayúsculas del correo no elude el contador.
- Un ingreso con contraseña válida sigue bloqueado al alcanzar el límite dentro de la ventana.
- Tras envejecer exclusivamente los intentos de esa cuenta de prueba a 16 minutos, el ingreso válido vuelve a permitirse y limpia sus intentos. No se alteró el reloj del servidor ni cuentas de Supabase.
- Un token con vencimiento pasado deja de permitir acceso al panel y redirige al ingreso con aviso de sesión terminada.
- El usuario puede volver a ingresar y el logout no deja tokens vigentes autorizados de esa cuenta.

La prueba terminó correctamente, eliminó sus datos temporales y quedó incorporada a la suite integral para futuras ejecuciones. No se repitió toda la suite en esta sexta revisión, porque no hubo cambios de aplicación. Se mantuvieron sin cambios Supabase y el despliegue público.

También se inspeccionaron las consultas históricas de participantes/asignaciones, los permisos de mensajes y el manejo existente de fechas inválidas en la búsqueda. Esa inspección no constituye una prueba exhaustiva de todos los estados o de concurrencia.


## Séptima revisión: participantes históricos ocultos en Pago

Se reprodujo en la pantalla de Pago de un proyecto finalizado: la sección Participantes presentados aparecía vacía aunque los nombres, correos, documentos y teléfonos seguían guardados en `participante_proyecto`. La consulta exigía `retiro_en IS NULL`, pero finalizar o cancelar cierra todas las participaciones. Ese filtro también ocultaba individualmente a quien se retiraba de un proyecto que continuaba activo.

La consulta de Pago ahora conserva todos los participantes presentados y su orden estable por plaza, ingreso e ID. La vista distingue Participación vigente de Participación cerrada, mostrando la fecha de cierre en Bogotá. No se modifica la condición de integrante vigente usada para autorizar envíos ni se reactivan participaciones.

La prueba `python -u scripts/pruebas_pago_historico.py` falló antes del cambio al buscar el nombre histórico y pasó después de reconstruir el contenedor. Contrasta los datos conservados con la sección HTML para un proyecto activo, otro cancelado y otro finalizado; comprueba nombre, correo, documento y teléfono cuando existen. Verifica además que Secretaría no reciba formularios de envío o aprobación.

El verificador MVC de 51 rutas pasó. La matriz de permisos de esta revisión terminó correctamente para los cinco roles, con 731 comprobaciones adicionales. La prueba nueva quedó integrada en la suite completa para futuras ejecuciones; no se repitió toda la suite integral en esta revisión.

No requiere migración ni modificación de datos en Supabase. La corrección necesita desplegar el modelo y la vista JSP; no se realizó push ni despliegue remoto.


## Octava revisión: versiones incorrectas en los detalles históricos de fase II

El detalle emergente de Propuesta II e Informe II reutilizaba siempre la última entrega de su fase I. Después de un rechazo y reenvío al director, mostraba el documento corregido en la fase II anterior, aunque esa corrección todavía no había llegado al evaluador. El reporte de rechazo anterior y los archivos mostrados podían corresponder a entregas distintas.

La consulta ahora determina por separado la última entrega de cada fase. Para la fase II solo considera entregas que tienen una etapa de evaluador o Comité registrada. La fase I sigue mostrando la corrección más reciente. Cuando el director la aprueba y se abre la revisión del evaluador, la fase II pasa a mostrar ese nuevo conjunto. El detalle compara el destino de los documentos con el código concreto de la fase y explica este criterio en pantalla.

Validación específica: `python -u scripts/pruebas_documentos_fases.py` ejecuta el SQL real extraído del modelo con fixtures en transacciones revertidas, exclusivamente en `grado_pruebas`. Comprueba propuesta e informe antes y después de que la corrección llegue al evaluador. Falló con la consulta anterior y pasó con la corregida. No persiste proyectos o documentos de prueba; las secuencias locales pueden avanzar. La prueba quedó incorporada a la suite integral para futuras ejecuciones.

El verificador MVC de 51 rutas y `git diff --check` pasaron. Se reconstruyó el contenedor y la matriz HTTP de los cinco roles pasó sus 731 comprobaciones adicionales. No se volvió a ejecutar toda la suite integral en esta revisión. La prueba SQL no se presenta como una inspección visual del popover en navegador.

No requiere migración ni cambios de datos en Supabase. Es necesario desplegar las JSP actualizadas para aplicar la corrección en Vercel; no se realizó push ni despliegue remoto.


## Novena revisión: aviso de corrección activo en un proyecto cerrado

Se reprodujo por HTTP que el seguimiento de un proyecto cerrado con corrección pendiente seguía anunciando “Si se supera, recibirás una alerta y podrás reenviar”. El estado cerrado ya impedía los envíos: era un mensaje contradictorio, no un permiso de escritura indebido.

La vista ahora mantiene el aviso de plazo/reenvío solo para proyectos activos; en pausa explica que la corrección está suspendida; en proyectos cerrados conserva la fecha como referencia histórica sin prometer nuevas alertas ni reenvíos. No cambian las funciones de negocio, las fechas ni los permisos.

`python -u scripts/pruebas_correccion_proyecto_cerrado.py` falló antes del cambio y pasó después de reconstruir el contenedor. La prueba simula una corrección sin reenvío en un proyecto cerrado del entorno local y restaura el dato original en finally; verifica el mensaje histórico y la ausencia de formulario de envío. No utiliza Supabase. Quedó integrada en la suite para próximas ejecuciones.

Pasaron también MVC (51 rutas) y `git diff --check`. No se repitieron la suite completa ni la matriz de roles en esta revisión, limitada a presentación. La rama de pausa se inspeccionó en código; esta prueba específica ejerce el caso cerrado.

No requiere migración en Supabase. Falta desplegar la JSP actualizada en el aplicativo público; no se realizó push ni despliegue remoto.
