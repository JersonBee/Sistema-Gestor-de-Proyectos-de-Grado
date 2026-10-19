-- Valida contenido visible en reportes de Pago/revisión y motivos/respuestas de solicitudes.
-- No modifica registros existentes, firmas ni permisos.
BEGIN;

CREATE OR REPLACE FUNCTION grado.decidir_pago(p_token text,p_proyecto bigint,p_entrega bigint,p_decision text,p_reporte text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, pg_temp AS $$
DECLARE actor record; proyecto_actual record; ciclo bigint; revision bigint; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN
  RETURN QUERY SELECT false,'Solo el Comité puede revisar el pago.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT * INTO proyecto_actual FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 SELECT c.id INTO ciclo FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id JOIN proyecto_fase f ON f.id=e.fase_origen_id
 WHERE e.id=p_entrega AND e.proyecto_id=p_proyecto AND f.fase_codigo='pago' AND f.finalizada_en IS NULL AND c.finalizado_en IS NULL;
 IF proyecto_actual.estado IS DISTINCT FROM 'activo' OR ciclo IS NULL THEN
  RETURN QUERY SELECT false,'La entrega ya fue revisada o el proyecto no está activo.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('aprobado','rechazado') OR nullif(regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL THEN
  RETURN QUERY SELECT false,'Selecciona una decisión y escribe el reporte para el estudiante.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO revision_entrega(ciclo_id,etapa,responsable_id,decision,reporte_respuesta,decidida_en)
 VALUES(ciclo,'comite',actor.id,p_decision,regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),CURRENT_TIMESTAMP) RETURNING id INTO revision;
 UPDATE ciclo_revision SET finalizado_en=CURRENT_TIMESTAMP WHERE id=ciclo;
 UPDATE proyecto_fase SET estado=p_decision WHERE proyecto_id=p_proyecto AND fase_codigo='pago';
 IF p_decision='aprobado' THEN
  UPDATE datos_pago SET aprobado_por=actor.id,aprobado_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto;
 ELSE
  INSERT INTO plazo_correccion(revision_id,inicio_en,limite_en) VALUES(revision,CURRENT_TIMESTAMP,limite_dias_calendario(CURRENT_TIMESTAMP,3));
 END IF;
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,actor.id,'usuario','decidir_pago','revision_entrega',revision,jsonb_build_object('decision',p_decision,'reporte',regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'))) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo)
 SELECT evento,pp.estudiante_id,'El Comité revisó el pago',p_decision||': '||regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM participante_proyecto pp WHERE pp.proyecto_id=p_proyecto AND pp.retiro_en IS NULL;
 RETURN QUERY SELECT true,'Decisión guardada sobre el conjunto completo.'::text,p_proyecto;
END; $$;

CREATE OR REPLACE FUNCTION grado.decidir_revision(p_token text,p_revision bigint,p_decision text,p_reporte text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; r record; proyecto_id_revision bigint; siguiente text; segunda text; docente bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT e.proyecto_id INTO proyecto_id_revision FROM revision_entrega re JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id WHERE re.id=p_revision;
 SELECT * INTO p FROM proyecto WHERE id=proyecto_id_revision FOR UPDATE;
 IF actor.id IS NULL OR actor.rol_codigo NOT IN('director','evaluador','comite') OR NOT coalesce(puede_consultar_proyecto(actor.id,p.id),false) THEN
  RETURN QUERY SELECT false,'No tienes permiso para revisar esta entrega.'::text,NULL::bigint; RETURN;
 END IF;
 PERFORM procesar_plazos_proyecto(p.id,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p.id;
 SELECT re.*,e.fase_origen_id,f.fase_codigo INTO r FROM revision_entrega re JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id JOIN proyecto_fase f ON f.id=e.fase_origen_id
  WHERE re.id=p_revision AND re.decision IS NULL AND c.finalizado_en IS NULL;
 IF p.estado<>'activo' OR r.id IS NULL OR r.etapa<>actor.rol_codigo OR r.fase_codigo NOT IN('propuesta_1','informe_1')
  OR (r.etapa<>'comite' AND (r.responsable_id<>actor.id OR NOT EXISTS(SELECT 1 FROM asignacion_proyecto ap WHERE ap.proyecto_id=p.id AND ap.docente_id=actor.id AND ap.funcion=r.etapa AND ap.fin_en IS NULL))) THEN
  RETURN QUERY SELECT false,'La revisión no está disponible para tu rol o ya terminó.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision IS NULL OR p_decision NOT IN('aprobado','rechazado') OR nullif(regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL THEN
  RETURN QUERY SELECT false,'Selecciona una decisión y escribe el reporte de respuesta.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision='rechazado' THEN
  PERFORM devolver_revision(r.id,'rechazado',regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),actor.id,CURRENT_TIMESTAMP);
  RETURN QUERY SELECT true,'Correcciones enviadas al estudiante. El ciclo reinicia con el director.'::text,p.id; RETURN;
 END IF;
 segunda:=CASE WHEN r.fase_codigo='propuesta_1' THEN 'propuesta_2' ELSE 'informe_2' END;
 IF r.etapa='director' THEN
  SELECT ap.docente_id INTO docente FROM asignacion_proyecto ap JOIN usuario u ON u.id=ap.docente_id WHERE ap.proyecto_id=p.id AND ap.funcion='evaluador' AND ap.fin_en IS NULL AND u.estado='activo' AND u.rol_codigo='evaluador';
  IF docente IS NULL THEN RETURN QUERY SELECT false,'No hay un evaluador activo asignado.'::text,NULL::bigint; RETURN; END IF;
 END IF;
 UPDATE revision_entrega SET decision='aprobado',reporte_respuesta=regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),decidida_en=CURRENT_TIMESTAMP,responsable_id=actor.id WHERE id=r.id;
 IF r.etapa='director' THEN
  UPDATE proyecto_fase SET estado='aprobado',finalizada_en=CURRENT_TIMESTAMP WHERE id=r.fase_origen_id;
  INSERT INTO proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(p.id,segunda,CURRENT_TIMESTAMP)
   ON CONFLICT(proyecto_id,fase_codigo) DO UPDATE SET estado=NULL,finalizada_en=NULL,iniciada_en=coalesce(proyecto_fase.iniciada_en,excluded.iniciada_en);
  INSERT INTO revision_entrega(ciclo_id,etapa,responsable_id,limite_en) VALUES(r.ciclo_id,'evaluador',docente,limite_dias_calendario(CURRENT_TIMESTAMP,5));
 ELSIF r.etapa='evaluador' THEN
  INSERT INTO revision_entrega(ciclo_id,etapa,responsable_id) VALUES(r.ciclo_id,'comite',NULL);
 ELSE
  UPDATE ciclo_revision SET finalizado_en=CURRENT_TIMESTAMP WHERE id=r.ciclo_id;
  UPDATE proyecto_fase SET estado='aprobado',finalizada_en=CURRENT_TIMESTAMP WHERE proyecto_id=p.id AND fase_codigo=segunda;
  siguiente:=CASE WHEN r.fase_codigo='propuesta_1' THEN 'informe_1' ELSE 'final' END;
  INSERT INTO proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(p.id,siguiente,CURRENT_TIMESTAMP);
  IF siguiente='informe_1' THEN
   UPDATE proyecto SET inicio_vigencia_en=CURRENT_TIMESTAMP,informe_habilitado_en=habilitacion_informe(CURRENT_TIMESTAMP),vence_en=limite_dias_calendario(CURRENT_TIMESTAMP,180) WHERE id=p.id;
  ELSE UPDATE proyecto SET informe_aprobado_comite_en=CURRENT_TIMESTAMP WHERE id=p.id; END IF;
 END IF;
 PERFORM avisar_proyecto(p.id,actor.id,'aprobar_revision','revision_entrega',r.id,'Revisión aprobada',regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 RETURN QUERY SELECT true,CASE WHEN r.etapa='director' THEN 'El conjunto pasó al evaluador.' WHEN r.etapa='evaluador' THEN 'El conjunto pasó al Comité.' WHEN siguiente='informe_1' THEN 'Propuesta aprobada. Comenzó Informe I y su vigencia de 180 días.' ELSE 'Informe aprobado. El proyecto avanzó a la fase Final.' END,p.id;
END; $$;

CREATE OR REPLACE FUNCTION grado.crear_solicitud(p_token text,p_proyecto bigint,p_tipo text,p_descripcion text,p_preferido bigint)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; nueva bigint; v_funcion text;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF actor.id IS NULL OR actor.rol_codigo<>'estudiante' OR NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=actor.id AND retiro_en IS NULL) THEN
  RETURN QUERY SELECT false,'Solo los participantes vigentes pueden enviar solicitudes.'::text,NULL::bigint; RETURN;
 END IF;
 PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
 IF p.estado IS DISTINCT FROM 'activo' OR p_tipo IS NULL OR p_tipo NOT IN('cambio_director','cambio_evaluador','retiro','reclamo','queja','solicitud') OR nullif(regexp_replace(p_descripcion, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR length(p_descripcion)>12000 THEN
  RETURN QUERY SELECT false,'Selecciona un proyecto activo, un tipo válido y escribe el motivo.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_tipo IN('cambio_director','cambio_evaluador') THEN
  v_funcion:=replace(p_tipo,'cambio_','');
  IF NOT EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND asignacion_proyecto.funcion=v_funcion AND fin_en IS NULL)
   OR NOT EXISTS(SELECT 1 FROM docente_apto_idea a JOIN usuario u ON u.id=a.docente_id WHERE a.idea_id=p.idea_id AND a.docente_id=p_preferido AND u.rol_codigo=v_funcion)
   OR EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND docente_id=p_preferido AND fin_en IS NULL) THEN
   RETURN QUERY SELECT false,'Selecciona otro docente apto para la función solicitada.'::text,NULL::bigint; RETURN;
  END IF;
 END IF;
 INSERT INTO solicitud(proyecto_id,solicitante_id,tipo,descripcion,docente_preferido_id)
 VALUES(p_proyecto,actor.id,p_tipo,regexp_replace(p_descripcion, '^[[:space:]]+|[[:space:]]+$', '', 'g'),CASE WHEN p_tipo IN('cambio_director','cambio_evaluador') THEN p_preferido ELSE NULL END) RETURNING id INTO nueva;
 PERFORM avisar_proyecto(p_proyecto,actor.id,'crear_solicitud','solicitud',nueva,'Nueva solicitud para el Comité',replace(p_tipo,'_',' ')||': '||regexp_replace(p_descripcion, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 RETURN QUERY SELECT true,'Solicitud enviada al Comité.'::text,p_proyecto;
END; $$;

CREATE OR REPLACE FUNCTION grado.decidir_solicitud(p_token text,p_solicitud bigint,p_decision text,p_respuesta text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; s record; p record; pid bigint; v_funcion text; anterior bigint; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN RETURN QUERY SELECT false,'Solo el Comité puede resolver solicitudes.'::text,NULL::bigint; RETURN; END IF;
 SELECT proyecto_id INTO pid FROM solicitud WHERE id=p_solicitud;
 SELECT * INTO p FROM proyecto WHERE id=pid FOR UPDATE;
 PERFORM procesar_plazos_proyecto(pid,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=pid;
 SELECT * INTO s FROM solicitud WHERE id=p_solicitud FOR UPDATE;
 IF p.estado IS DISTINCT FROM 'activo' OR s.id IS NULL OR s.estado<>'pendiente' THEN RETURN QUERY SELECT false,'La solicitud ya fue resuelta o el proyecto no está activo.'::text,NULL::bigint; RETURN; END IF;
 IF p_decision IS NULL OR nullif(regexp_replace(p_respuesta, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR
  (s.tipo IN('cambio_director','cambio_evaluador','retiro') AND p_decision NOT IN('aprobada','rechazada')) OR
  (s.tipo NOT IN('cambio_director','cambio_evaluador','retiro') AND p_decision NOT IN('atendida','rechazada')) THEN
  RETURN QUERY SELECT false,'Selecciona una decisión válida y escribe la respuesta.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision='aprobada' AND NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=pid AND estudiante_id=s.solicitante_id AND retiro_en IS NULL) THEN
  RETURN QUERY SELECT false,'El solicitante ya no participa en este proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision='aprobada' AND s.tipo IN('cambio_director','cambio_evaluador') THEN
  v_funcion:=replace(s.tipo,'cambio_','');
  SELECT docente_id INTO anterior FROM asignacion_proyecto ap WHERE ap.proyecto_id=pid AND ap.funcion=v_funcion AND ap.fin_en IS NULL;
  IF anterior IS NULL OR NOT EXISTS(SELECT 1 FROM docente_apto_idea a JOIN usuario u ON u.id=a.docente_id WHERE a.idea_id=p.idea_id AND a.docente_id=s.docente_preferido_id AND u.rol_codigo=v_funcion)
   OR EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=pid AND docente_id=s.docente_preferido_id AND fin_en IS NULL) THEN
   RETURN QUERY SELECT false,'El docente preferido ya no está disponible o no coincide con la idea.'::text,NULL::bigint; RETURN;
  END IF;
  UPDATE asignacion_proyecto SET fin_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid AND asignacion_proyecto.funcion=v_funcion AND fin_en IS NULL;
  INSERT INTO asignacion_proyecto(proyecto_id,docente_id,funcion,asignado_por) VALUES(pid,s.docente_preferido_id,v_funcion,actor.id);
  UPDATE revision_entrega r SET responsable_id=s.docente_preferido_id,asignada_en=CURRENT_TIMESTAMP,limite_en=limite_dias_calendario(CURRENT_TIMESTAMP,5)
   FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id WHERE r.ciclo_id=c.id AND e.proyecto_id=pid AND r.etapa=v_funcion AND r.decision IS NULL AND c.finalizado_en IS NULL;
  PERFORM avisar_proyecto(pid,actor.id,'cambiar_docente','solicitud',s.id,'Cambió el docente asignado',v_funcion||': '||(SELECT nombre FROM usuario WHERE id=anterior)||' → '||(SELECT nombre FROM usuario WHERE id=s.docente_preferido_id)||'. La revisión pendiente dispone de cinco días calendario desde la reasignación.');
 END IF;
 UPDATE solicitud SET estado=p_decision WHERE id=s.id;
 INSERT INTO respuesta_solicitud(solicitud_id,responsable_id,estado_resultante,respuesta) VALUES(s.id,actor.id,p_decision,regexp_replace(p_respuesta, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 PERFORM avisar_proyecto(pid,actor.id,'decidir_solicitud','solicitud',s.id,'El Comité respondió una solicitud',replace(s.tipo,'_',' ')||' · '||p_decision||': '||regexp_replace(p_respuesta, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 IF p_decision='aprobada' AND s.tipo='retiro' THEN
  UPDATE participante_proyecto SET retiro_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid AND estudiante_id=s.solicitante_id AND retiro_en IS NULL;
  PERFORM cerrar_solicitudes_pendientes(pid,actor.id,'El solicitante se retiró. No se aplicaron los cambios pendientes.',s.solicitante_id);
  IF NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=pid AND retiro_en IS NULL) THEN
   evento:=avisar_proyecto(pid,actor.id,'cancelar_por_retiro','proyecto',pid,'Proyecto cancelado por retiro','Se aprobó el retiro del último integrante. La idea vuelve al banco.');
   INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,s.solicitante_id,'Proyecto cancelado por retiro','Se aprobó tu retiro como último integrante. La idea vuelve al banco.') ON CONFLICT DO NOTHING;
   UPDATE revision_entrega r SET decision='aplicado',decidida_en=CURRENT_TIMESTAMP,reporte_respuesta='Proyecto cancelado por retiro de su último integrante.'
    FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id WHERE r.ciclo_id=c.id AND e.proyecto_id=pid AND r.decision IS NULL;
   UPDATE ciclo_revision c SET finalizado_en=CURRENT_TIMESTAMP FROM entrega_revision e WHERE e.id=c.entrega_id AND e.proyecto_id=pid AND c.finalizado_en IS NULL;
   UPDATE proyecto_fase SET estado=coalesce(estado,'aplicado'),finalizada_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid AND iniciada_en IS NOT NULL AND finalizada_en IS NULL;
   UPDATE asignacion_proyecto SET fin_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid AND fin_en IS NULL;
   UPDATE proyecto SET estado='cancelado' WHERE id=pid;
  END IF;
 END IF;
 RETURN QUERY SELECT true,'Respuesta guardada y cambios aplicados cuando corresponde.'::text,pid;
END; $$;

COMMIT;
