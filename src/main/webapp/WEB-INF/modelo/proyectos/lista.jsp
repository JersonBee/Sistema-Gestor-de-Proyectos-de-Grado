<sql:query var="lista" dataSource="${bd}">
 WITH filtros AS(SELECT CAST(? AS bigint) AS usuario,CAST(? AS text) AS q,CAST(? AS text) AS estudiante,CAST(? AS text) AS director,CAST(? AS text) AS evaluador,CAST(? AS text) AS modalidad,CAST(? AS text) AS estado,CAST(? AS text) AS fase,CAST(nullif(CAST(? AS text),'') AS date) AS desde,CAST(nullif(CAST(? AS text),'') AS date) AS hasta)
 SELECT p.id,p.titulo,p.estado,m.nombre AS modalidad,coalesce(actual.nombre,'Por iniciar') AS fase,to_char(p.creado_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY') AS fecha
 FROM grado.proyecto p JOIN grado.modalidad m ON m.id=p.modalidad_id CROSS JOIN filtros x
 LEFT JOIN LATERAL(SELECT f.nombre,f.codigo FROM grado.proyecto_fase pf JOIN grado.fase f ON f.codigo=pf.fase_codigo WHERE pf.proyecto_id=p.id AND pf.iniciada_en IS NOT NULL ORDER BY (pf.finalizada_en IS NULL) DESC,f.orden DESC LIMIT 1) actual ON true
 WHERE grado.puede_consultar_proyecto(x.usuario,p.id)
 AND (x.q='' OR p.titulo ILIKE '%'||x.q||'%' OR p.id::text=x.q)
 AND (x.estudiante='' OR EXISTS(SELECT 1 FROM grado.participante_proyecto pp JOIN grado.usuario u ON u.id=pp.estudiante_id WHERE pp.proyecto_id=p.id AND (u.nombre ILIKE '%'||x.estudiante||'%' OR u.correo ILIKE '%'||x.estudiante||'%' OR pp.nombre_en_pago ILIKE '%'||x.estudiante||'%')))
 AND (x.director='' OR EXISTS(SELECT 1 FROM grado.asignacion_proyecto ap JOIN grado.usuario u ON u.id=ap.docente_id WHERE ap.proyecto_id=p.id AND ap.funcion='director' AND u.nombre ILIKE '%'||x.director||'%'))
 AND (x.evaluador='' OR EXISTS(SELECT 1 FROM grado.asignacion_proyecto ap JOIN grado.usuario u ON u.id=ap.docente_id WHERE ap.proyecto_id=p.id AND ap.funcion='evaluador' AND u.nombre ILIKE '%'||x.evaluador||'%'))
 AND (x.modalidad='' OR m.id::text=x.modalidad) AND (x.estado='' OR p.estado=x.estado) AND (x.fase='' OR actual.codigo=x.fase)
 AND (x.desde IS NULL OR (p.creado_en AT TIME ZONE 'America/Bogota')::date>=x.desde) AND (x.hasta IS NULL OR (p.creado_en AT TIME ZONE 'America/Bogota')::date<=x.hasta)
 ORDER BY p.creado_en DESC,p.id DESC LIMIT 21 OFFSET CAST(? AS integer)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${empty param.q ? '' : param.q}" /><sql:param value="${empty param.estudiante ? '' : param.estudiante}" /><sql:param value="${empty param.director ? '' : param.director}" /><sql:param value="${empty param.evaluador ? '' : param.evaluador}" /><sql:param value="${empty param.modalidad ? '' : param.modalidad}" /><sql:param value="${empty param.estado ? '' : param.estado}" /><sql:param value="${empty param.fase ? '' : param.fase}" /><sql:param value="${empty param.desde ? '' : param.desde}" /><sql:param value="${empty param.hasta ? '' : param.hasta}" /><sql:param value="${(pagina-1)*20}" />
</sql:query>
