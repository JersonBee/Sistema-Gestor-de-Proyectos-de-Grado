<sql:query var="ideas" dataSource="${bd}">
 SELECT i.id,i.titulo,i.estado,m.nombre AS modalidad,a.nombre AS area,l.nombre AS linea,u.nombre AS autor,
 EXISTS(SELECT 1 FROM grado.proyecto p WHERE p.idea_id=i.id AND p.estado<>'cancelado') AS reservada
 FROM grado.idea i JOIN grado.modalidad m ON m.id=i.modalidad_id JOIN grado.area_experiencia a ON a.id=i.area_id
 JOIN grado.linea_investigacion l ON l.id=i.linea_id JOIN grado.usuario u ON u.id=i.autor_id
 WHERE grado.puede_consultar_idea(CAST(? AS bigint),i.id) AND (CAST(? AS text)='' OR i.titulo ILIKE '%'||CAST(? AS text)||'%')
 AND (CAST(? AS text)<>'propias' OR i.autor_id=CAST(? AS bigint))
 ORDER BY i.creado_en DESC,i.id DESC LIMIT 21 OFFSET CAST(? AS integer)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${empty param.q ? '' : param.q}" /><sql:param value="${empty param.q ? '' : param.q}" />
 <sql:param value="${empty param.vista ? '' : param.vista}" /><sql:param value="${usuarioActual.id}" /><sql:param value="${(pagina-1)*20}" />
</sql:query>
