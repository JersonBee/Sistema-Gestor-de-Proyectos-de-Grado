<sql:query var="proyectoConsulta" dataSource="${bd}">SELECT p.id,p.titulo,p.estado,p.idea_id,p.finalizado_en,u.nombre AS finalizado_por,
 EXISTS(SELECT 1 FROM grado.participante_proyecto pp WHERE pp.proyecto_id=p.id AND pp.estudiante_id=CAST(? AS bigint) AND pp.retiro_en IS NULL) AS integrante,
 EXISTS(SELECT 1 FROM grado.asignacion_proyecto ap WHERE ap.proyecto_id=p.id AND ap.docente_id=CAST(? AS bigint) AND ap.funcion='director' AND ap.fin_en IS NULL) AS es_director,
 EXISTS(SELECT 1 FROM grado.proyecto_fase pf WHERE pf.proyecto_id=p.id AND pf.fase_codigo='final' AND pf.iniciada_en IS NOT NULL) AS fase_final
 FROM grado.proyecto p LEFT JOIN grado.usuario u ON u.id=p.finalizado_por WHERE p.id=CAST(? AS bigint) AND grado.puede_consultar_proyecto(CAST(? AS bigint),p.id)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${usuarioActual.id}" /><sql:param value="${param.id}" /><sql:param value="${usuarioActual.id}" /></sql:query>
