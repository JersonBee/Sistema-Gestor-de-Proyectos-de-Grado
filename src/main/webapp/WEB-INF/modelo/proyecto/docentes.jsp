<sql:query var="docentes" dataSource="${bd}">
 SELECT funciones.funcion,ultima.nombre,(ultima.fin_en IS NOT NULL) AS historica
 FROM grado.proyecto p CROSS JOIN (VALUES ('director'),('evaluador')) funciones(funcion)
 LEFT JOIN LATERAL (
  SELECT u.nombre,a.fin_en FROM grado.asignacion_proyecto a JOIN grado.usuario u ON u.id=a.docente_id
  WHERE a.proyecto_id=p.id AND a.funcion=funciones.funcion
   AND (a.fin_en IS NULL OR p.estado IN ('cancelado','finalizado'))
  ORDER BY (a.fin_en IS NULL) DESC,a.inicio_en DESC,a.id DESC LIMIT 1
 ) ultima ON true
 WHERE p.id=CAST(? AS bigint) AND grado.puede_consultar_proyecto(CAST(? AS bigint),p.id)
 ORDER BY funciones.funcion
 <sql:param value="${param.id}" /><sql:param value="${usuarioActual.id}" />
</sql:query>
