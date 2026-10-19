<sql:query var="documentosFases" dataSource="${bd}">
 WITH base AS(SELECT e.id,e.numero,f.fase_codigo FROM grado.entrega_revision e
 JOIN grado.proyecto_fase f ON f.id=e.fase_origen_id WHERE e.proyecto_id=CAST(? AS bigint)),
 candidatas AS(
  SELECT id,numero,fase_codigo AS origen FROM base
  UNION ALL
  SELECT b.id,b.numero,CASE WHEN b.fase_codigo='propuesta_1' THEN 'propuesta_2' ELSE 'informe_2' END
  FROM base b WHERE b.fase_codigo IN('propuesta_1','informe_1')
   AND EXISTS(SELECT 1 FROM grado.ciclo_revision c JOIN grado.revision_entrega r ON r.ciclo_id=c.id
    WHERE c.entrega_id=b.id AND r.etapa IN('evaluador','comite'))
 ),ultima AS(SELECT DISTINCT ON(origen) id,numero,origen FROM candidatas ORDER BY origen,numero DESC,id DESC)
 SELECT ultima.origen,t.nombre,d.etiqueta,v.id AS version_id,v.numero,v.url,ultima.numero AS entrega
 FROM ultima JOIN grado.entrega_documento_version ed ON ed.entrega_id=ultima.id
 JOIN grado.documento d ON d.id=ed.documento_id JOIN grado.documento_version v ON v.id=ed.version_id JOIN grado.tipo_documento t ON t.codigo=d.tipo_codigo
 UNION ALL
 SELECT f.fase_codigo,t.nombre,d.etiqueta,v.id,v.numero,v.url,NULL::integer
 FROM grado.documento d JOIN grado.proyecto_fase f ON f.id=d.proyecto_fase_id JOIN grado.tipo_documento t ON t.codigo=d.tipo_codigo
 JOIN LATERAL(SELECT dv.* FROM grado.documento_version dv WHERE dv.documento_id=d.id ORDER BY dv.numero DESC LIMIT 1) v ON true
 WHERE d.proyecto_id=CAST(? AS bigint) AND f.fase_codigo='final'
 ORDER BY origen,nombre,etiqueta
 <sql:param value="${param.id}" /><sql:param value="${param.id}" />
</sql:query>
