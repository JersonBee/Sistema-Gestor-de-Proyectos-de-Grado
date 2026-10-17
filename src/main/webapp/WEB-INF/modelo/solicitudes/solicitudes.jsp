<sql:query var="solicitudes" dataSource="${bd}">SELECT s.id,s.tipo,s.descripcion,s.estado,u.nombre AS solicitante,d.nombre AS preferido,
 to_char(s.creado_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS fecha,
 coalesce((SELECT r.respuesta FROM grado.respuesta_solicitud r WHERE r.solicitud_id=s.id ORDER BY r.creado_en DESC,r.id DESC LIMIT 1),
 (SELECT e.datos_nuevos->>'detalle' FROM grado.evento_auditoria e WHERE e.entidad='solicitud' AND e.entidad_id=s.id AND e.accion='cerrar_solicitud' ORDER BY e.id DESC LIMIT 1)) AS respuesta
 FROM grado.solicitud s JOIN grado.usuario u ON u.id=s.solicitante_id LEFT JOIN grado.usuario d ON d.id=s.docente_preferido_id
 WHERE s.proyecto_id=CAST(? AS bigint) ORDER BY s.creado_en DESC,s.id DESC LIMIT 21 OFFSET CAST(? AS integer)<sql:param value="${param.id}" /><sql:param value="${(pagina-1)*20}" /></sql:query>
