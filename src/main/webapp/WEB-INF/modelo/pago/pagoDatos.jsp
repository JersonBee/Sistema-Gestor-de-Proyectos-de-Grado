<sql:query var="pagoDatos" dataSource="${bd}">SELECT p.id,p.titulo,p.estado,p.idea_id,dp.aprobado_en,u.nombre AS director_propuesto,f.finalizada_en,
 EXISTS(SELECT 1 FROM grado.participante_proyecto pp WHERE pp.proyecto_id=p.id AND pp.estudiante_id=CAST(? AS bigint) AND pp.retiro_en IS NULL) AS integrante
 FROM grado.proyecto p JOIN grado.datos_pago dp ON dp.proyecto_id=p.id JOIN grado.proyecto_fase f ON f.proyecto_id=p.id AND f.fase_codigo='pago'
 LEFT JOIN grado.usuario u ON u.id=dp.director_propuesto_id WHERE p.id=CAST(? AS bigint) AND grado.puede_consultar_proyecto(CAST(? AS bigint),p.id)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${param.id}" /><sql:param value="${usuarioActual.id}" /></sql:query>
