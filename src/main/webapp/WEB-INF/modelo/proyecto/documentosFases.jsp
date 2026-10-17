<sql:query var="documentosFases" dataSource="${bd}">
 WITH ultima AS(SELECT DISTINCT ON(e.fase_origen_id) e.id,e.fase_origen_id,e.numero FROM grado.entrega_revision e
 WHERE e.proyecto_id=CAST(? AS bigint) ORDER BY e.fase_origen_id,e.numero DESC)
 SELECT f.fase_codigo AS origen,t.nombre,d.etiqueta,v.id AS version_id,v.numero,v.url,ultima.numero AS entrega
 FROM ultima JOIN grado.proyecto_fase f ON f.id=ultima.fase_origen_id JOIN grado.entrega_documento_version ed ON ed.entrega_id=ultima.id
 JOIN grado.documento d ON d.id=ed.documento_id JOIN grado.documento_version v ON v.id=ed.version_id JOIN grado.tipo_documento t ON t.codigo=d.tipo_codigo
 UNION ALL
 SELECT f.fase_codigo,t.nombre,d.etiqueta,v.id,v.numero,v.url,NULL::integer
 FROM grado.documento d JOIN grado.proyecto_fase f ON f.id=d.proyecto_fase_id JOIN grado.tipo_documento t ON t.codigo=d.tipo_codigo
 JOIN LATERAL(SELECT dv.* FROM grado.documento_version dv WHERE dv.documento_id=d.id ORDER BY dv.numero DESC LIMIT 1) v ON true
 WHERE d.proyecto_id=CAST(? AS bigint) AND f.fase_codigo='final'
 ORDER BY origen,nombre,etiqueta
 <sql:param value="${param.id}" /><sql:param value="${param.id}" />
</sql:query>
