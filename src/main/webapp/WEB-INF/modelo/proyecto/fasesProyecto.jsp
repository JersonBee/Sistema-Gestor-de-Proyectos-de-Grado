<sql:query var="fasesProyecto" dataSource="${bd}">SELECT f.codigo,f.nombre,f.orden,pf.estado,pf.iniciada_en,pf.finalizada_en,
 CASE f.codigo WHEN 'propuesta_2' THEN 'propuesta_1' WHEN 'informe_2' THEN 'informe_1' ELSE f.codigo END AS origen,
 to_char(pf.iniciada_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS inicio,
 to_char(pf.finalizada_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS fin
 FROM grado.fase f LEFT JOIN grado.proyecto_fase pf ON pf.fase_codigo=f.codigo AND pf.proyecto_id=CAST(? AS bigint)
 ORDER BY f.orden<sql:param value="${param.id}" /></sql:query>
