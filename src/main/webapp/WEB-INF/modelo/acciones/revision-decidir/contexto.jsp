<sql:query var="contextoRevision" dataSource="${bd}">
 SELECT r.id FROM grado.revision_entrega r
 JOIN grado.ciclo_revision c ON c.id=r.ciclo_id
 JOIN grado.entrega_revision e ON e.id=c.entrega_id
 JOIN grado.proyecto_fase f ON f.id=e.fase_origen_id
 WHERE r.id=CAST(? AS bigint) AND e.proyecto_id=CAST(? AS bigint)
 AND f.fase_codigo=CASE WHEN CAST(? AS text)='propuesta' THEN 'propuesta_1' ELSE 'informe_1' END
 <sql:param value="${param.revision}" /><sql:param value="${param.id}" /><sql:param value="${param.tipo}" />
</sql:query>
