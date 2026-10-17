<sql:query var="info" dataSource="${bd}">SELECT p.id,p.titulo,p.estado,f.id AS fase_id,f.finalizada_en,
 to_char(p.informe_habilitado_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS habilitado,
 to_char(p.vence_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS vence,p.informe_aprobado_comite_en,
 (p.informe_habilitado_en IS NOT NULL AND CURRENT_TIMESTAMP>=p.informe_habilitado_en) AS informe_disponible,
 EXISTS(SELECT 1 FROM grado.participante_proyecto pp WHERE pp.proyecto_id=p.id AND pp.estudiante_id=CAST(? AS bigint) AND pp.retiro_en IS NULL) AS integrante
 FROM grado.proyecto p LEFT JOIN grado.proyecto_fase f ON f.proyecto_id=p.id AND f.fase_codigo=CAST(? AS text)
 WHERE p.id=CAST(? AS bigint) AND grado.puede_consultar_proyecto(CAST(? AS bigint),p.id)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${origen}" /><sql:param value="${param.id}" /><sql:param value="${usuarioActual.id}" /></sql:query>
