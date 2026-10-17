<sql:query var="estadoResumen" dataSource="${bd}">
 SELECT p.id,p.titulo,p.estado,m.nombre AS modalidad,actual.codigo AS fase_codigo,actual.nombre AS fase,
 actual.estado AS resultado_fase,dp.aprobado_en AS pago_aprobado,
 pendiente.etapa,pendiente.responsable,pendiente.responsable_id,
 to_char(pendiente.limite_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS limite_revision,
 to_char(correccion.limite_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS limite_correccion,
 correccion.limite_en <= CURRENT_TIMESTAMP AS correccion_vencida,
 to_char(p.informe_habilitado_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS habilitado,
 p.informe_habilitado_en <= CURRENT_TIMESTAMP AS informe_disponible,
 to_char(p.vence_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS vence,
 p.informe_aprobado_comite_en,
 (SELECT string_agg(pp.nombre_en_pago,', ' ORDER BY pp.plaza) FROM grado.participante_proyecto pp WHERE pp.proyecto_id=p.id AND pp.retiro_en IS NULL) AS estudiantes,
 (SELECT count(*) FROM grado.solicitud so WHERE so.proyecto_id=p.id AND so.estado='pendiente') AS solicitudes_pendientes
 FROM grado.proyecto p JOIN grado.modalidad m ON m.id=p.modalidad_id
 LEFT JOIN grado.datos_pago dp ON dp.proyecto_id=p.id
 LEFT JOIN LATERAL(SELECT f.codigo,f.nombre,pf.estado FROM grado.proyecto_fase pf JOIN grado.fase f ON f.codigo=pf.fase_codigo
  WHERE pf.proyecto_id=p.id AND pf.iniciada_en IS NOT NULL ORDER BY (pf.finalizada_en IS NULL) DESC,f.orden DESC LIMIT 1) actual ON true
 LEFT JOIN LATERAL(SELECT r.etapa,r.responsable_id,r.limite_en,coalesce(u.nombre,'Comité') AS responsable
  FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id
  LEFT JOIN grado.usuario u ON u.id=r.responsable_id
  WHERE e.proyecto_id=p.id AND c.finalizado_en IS NULL AND r.decision IS NULL ORDER BY r.id DESC LIMIT 1) pendiente ON true
 LEFT JOIN LATERAL(SELECT pc.limite_en FROM grado.plazo_correccion pc JOIN grado.revision_entrega r ON r.id=pc.revision_id
  JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id JOIN grado.proyecto_fase pf ON pf.id=e.fase_origen_id
  WHERE e.proyecto_id=p.id AND pf.fase_codigo=actual.codigo AND pc.entrega_reenvio_id IS NULL ORDER BY pc.id DESC LIMIT 1) correccion ON true
 WHERE p.id=CAST(? AS bigint) AND grado.puede_consultar_proyecto(CAST(? AS bigint),p.id)
 <sql:param value="${param.id}" /><sql:param value="${usuarioActual.id}" />
</sql:query>
