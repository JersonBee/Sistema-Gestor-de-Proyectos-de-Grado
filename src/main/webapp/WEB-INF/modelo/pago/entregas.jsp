<sql:query var="entregas" dataSource="${bd}">SELECT e.id,e.numero,c.finalizado_en,r.decision,r.reporte_respuesta,u.nombre AS responsable,
 to_char(e.presentada_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS fecha
 FROM grado.entrega_revision e JOIN grado.proyecto_fase f ON f.id=e.fase_origen_id JOIN grado.ciclo_revision c ON c.entrega_id=e.id
 LEFT JOIN grado.revision_entrega r ON r.ciclo_id=c.id LEFT JOIN grado.usuario u ON u.id=r.responsable_id WHERE e.proyecto_id=CAST(? AS bigint) AND f.fase_codigo='pago' ORDER BY e.numero DESC
 <sql:param value="${param.id}" />
</sql:query>
