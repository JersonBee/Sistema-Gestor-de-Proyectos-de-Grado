<sql:query var="revisionesFases" dataSource="${bd}">
 SELECT CASE WHEN f.fase_codigo='pago' OR r.etapa='director' THEN f.fase_codigo
 WHEN f.fase_codigo='propuesta_1' THEN 'propuesta_2' ELSE 'informe_2' END AS fase_codigo,
 e.numero AS entrega,r.etapa,r.decision,r.reporte_respuesta,coalesce(u.nombre,'Comité') AS responsable,
 to_char(r.asignada_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS asignada,
 to_char(r.limite_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS limite,
 to_char(r.decidida_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS decidida
 FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id
 JOIN grado.proyecto_fase f ON f.id=e.fase_origen_id LEFT JOIN grado.usuario u ON u.id=r.responsable_id
 WHERE e.proyecto_id=CAST(? AS bigint) ORDER BY e.numero DESC,r.id DESC
 <sql:param value="${param.id}" />
</sql:query>
