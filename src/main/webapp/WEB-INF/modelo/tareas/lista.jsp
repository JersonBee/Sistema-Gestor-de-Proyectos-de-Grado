<sql:query var="tareas" dataSource="${bd}">
 WITH actor AS(SELECT id,rol_codigo FROM grado.usuario WHERE id=CAST(? AS bigint) AND estado='activo'),
 fases AS(SELECT p.id,p.titulo,p.informe_habilitado_en,p.creado_en,pf.id AS fase_id,f.codigo,f.nombre
  FROM grado.proyecto p JOIN grado.proyecto_fase pf ON pf.proyecto_id=p.id JOIN grado.fase f ON f.codigo=pf.fase_codigo
  WHERE p.estado='activo' AND pf.iniciada_en IS NOT NULL AND pf.finalizada_en IS NULL),
 pendientes AS(SELECT e.proyecto_id,r.etapa,r.responsable_id,r.limite_en,r.asignada_en
  FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id
  WHERE c.finalizado_en IS NULL AND r.decision IS NULL),
 bandeja AS(
  SELECT 'revision'::text AS tipo,f.titulo,'Revisar el conjunto · '||f.nombre AS accion,
   CASE WHEN f.codigo='pago' THEN '/pago.jsp' ELSE '/seguimiento.jsp' END AS destino,f.id AS recurso,
   CASE WHEN f.codigo LIKE 'informe%' THEN 'informe' ELSE 'propuesta' END AS recorrido,r.limite_en,r.asignada_en AS creada
  FROM pendientes r JOIN fases f ON f.id=r.proyecto_id CROSS JOIN actor a
  WHERE a.rol_codigo=r.etapa AND (a.rol_codigo='comite' OR a.id=r.responsable_id)
  UNION ALL
  SELECT 'entrega',f.titulo,'Presentar el conjunto · '||f.nombre,'/resumen.jsp',f.id,NULL,NULL,f.creado_en
  FROM fases f CROSS JOIN actor a WHERE a.rol_codigo='estudiante' AND f.codigo IN('pago','propuesta_1','informe_1')
   AND EXISTS(SELECT 1 FROM grado.participante_proyecto pp WHERE pp.proyecto_id=f.id AND pp.estudiante_id=a.id AND pp.retiro_en IS NULL)
   AND NOT EXISTS(SELECT 1 FROM pendientes r WHERE r.proyecto_id=f.id)
   AND (f.codigo<>'pago' OR NOT EXISTS(SELECT 1 FROM grado.datos_pago dp WHERE dp.proyecto_id=f.id AND dp.aprobado_en IS NOT NULL))
   AND (f.codigo<>'informe_1' OR CURRENT_TIMESTAMP>=f.informe_habilitado_en)
  UNION ALL
  SELECT 'asignacion',f.titulo,'Asignar director y evaluador','/pago.jsp',f.id,NULL,NULL,f.creado_en
  FROM fases f CROSS JOIN actor a JOIN grado.datos_pago dp ON dp.proyecto_id=f.id
  WHERE a.rol_codigo='comite' AND f.codigo='pago' AND dp.aprobado_en IS NOT NULL
  UNION ALL
  SELECT 'cierre',f.titulo,'Revisar el cierre del proyecto','/final.jsp',f.id,NULL,NULL,f.creado_en
  FROM fases f CROSS JOIN actor a WHERE a.rol_codigo='comite' AND f.codigo='final'
  UNION ALL
  SELECT 'idea',i.titulo,'Decidir la idea propuesta','/idea.jsp',i.id,NULL,NULL,i.creado_en
  FROM grado.idea i CROSS JOIN actor a WHERE a.rol_codigo='comite' AND i.estado='pendiente'
  UNION ALL
  SELECT 'solicitud',p.titulo,'Responder solicitud · '||s.tipo,'/solicitudes.jsp',p.id,NULL,NULL,s.creado_en
  FROM grado.solicitud s JOIN grado.proyecto p ON p.id=s.proyecto_id CROSS JOIN actor a
  WHERE a.rol_codigo='comite' AND s.estado='pendiente' AND p.estado='activo'
  UNION ALL
  SELECT 'acta','Acta '||ac.numero,'Aprobar el acta pendiente','/acta.jsp',ac.id,NULL,NULL,ac.creado_en
  FROM grado.acta ac CROSS JOIN actor a WHERE a.rol_codigo='comite' AND ac.aprobada_en IS NULL
   AND EXISTS(SELECT 1 FROM grado.acta_proyecto ap WHERE ap.acta_id=ac.id)
   AND NOT EXISTS(SELECT 1 FROM grado.acta_proyecto ap JOIN grado.proyecto p ON p.id=ap.proyecto_id WHERE ap.acta_id=ac.id AND p.estado='desactivado')
  UNION ALL
  SELECT 'mensaje',p.titulo,'Leer mensajes recibidos ('||count(*)||')','/mensajes.jsp',p.id,NULL,NULL,min(m.enviado_en)
  FROM grado.mensaje m JOIN grado.proyecto p ON p.id=m.proyecto_id CROSS JOIN actor a
  WHERE m.destinatario_id=a.id AND m.leido_en IS NULL AND grado.puede_consultar_proyecto(a.id,p.id)
  GROUP BY p.id,p.titulo
 )
 SELECT tipo,titulo,accion,destino,recurso,recorrido,
  to_char(limite_en AT TIME ZONE 'America/Bogota','DD/MM/YYYY HH24:MI') AS limite,
  limite_en<=CURRENT_TIMESTAMP AS vencida,count(*) OVER() AS total
 FROM bandeja ORDER BY limite_en NULLS LAST,creada,tipo,recurso LIMIT CAST(? AS integer) OFFSET CAST(? AS integer)
 <sql:param value="${usuarioActual.id}" /><sql:param value="${limiteTareas}" /><sql:param value="${(paginaTareas-1)*20}" />
</sql:query>
