-- Entregables opcionales, cierre por el Comité y solicitudes del proyecto.
BEGIN;
CREATE OR REPLACE FUNCTION grado.cerrar_solicitudes_pendientes(p_proyecto bigint,p_actor bigint,p_texto text,p_estudiante bigint DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE s record; evento bigint;
BEGIN
 FOR s IN UPDATE solicitud SET estado='atendida' WHERE proyecto_id=p_proyecto AND estado='pendiente'
  AND (p_estudiante IS NULL OR (solicitante_id=p_estudiante AND tipo IN('cambio_director','cambio_evaluador','retiro'))) RETURNING id,solicitante_id
 LOOP
  -- El cierre automático por vencimiento no tiene un responsable humano.
  INSERT INTO respuesta_solicitud(solicitud_id,responsable_id,estado_resultante,respuesta)
   SELECT s.id,p_actor,'atendida',p_texto WHERE p_actor IS NOT NULL;
  INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
  VALUES(p_proyecto,p_actor,CASE WHEN p_actor IS NULL THEN 'sistema' ELSE 'usuario' END,'cerrar_solicitud','solicitud',s.id,jsonb_build_object('detalle',p_texto)) RETURNING id INTO evento;
  INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,s.solicitante_id,'Solicitud cerrada sin aplicar cambios',p_texto);
 END LOOP;
END; $$;

CREATE OR REPLACE FUNCTION grado.cerrar_tramites_proyecto() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
BEGIN
 PERFORM cerrar_solicitudes_pendientes(NEW.id,NEW.finalizado_por,
  CASE WHEN NEW.estado='finalizado' THEN 'El Comité finalizó el proyecto. Esta solicitud pendiente queda cerrada sin aplicar cambios.'
  ELSE 'El proyecto fue cancelado. Esta solicitud pendiente queda cerrada sin aplicar cambios.' END);
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS proyecto_cerrar_tramites ON grado.proyecto;
CREATE TRIGGER proyecto_cerrar_tramites AFTER UPDATE OF estado ON grado.proyecto
 FOR EACH ROW WHEN(NEW.estado IN('cancelado','finalizado') AND OLD.estado IS DISTINCT FROM NEW.estado)
 EXECUTE FUNCTION grado.cerrar_tramites_proyecto();

CREATE OR REPLACE FUNCTION grado.guardar_entregable_final(p_token text,p_proyecto bigint,p_campo text,p_valor text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; fase_id bigint; doc bigint; version bigint; anterior text;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF actor.id IS NULL OR p_campo IS NULL OR p_campo NOT IN('manual_usuario','evidencia_publicacion','licencia','repositorio') THEN
  RETURN QUERY SELECT false,'No puedes registrar este entregable.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_campo='repositorio' THEN
  IF actor.rol_codigo<>'director' OR NOT EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND docente_id=actor.id AND funcion='director' AND fin_en IS NULL) THEN
   RETURN QUERY SELECT false,'El repositorio lo registra el director asignado.'::text,NULL::bigint; RETURN;
  END IF;
 ELSE
  IF actor.rol_codigo<>'estudiante' OR NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=actor.id AND retiro_en IS NULL) THEN
   RETURN QUERY SELECT false,'Los documentos finales los registra un participante vigente.'::text,NULL::bigint; RETURN;
  END IF;
 END IF;
 PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
 SELECT id INTO fase_id FROM proyecto_fase WHERE proyecto_id=p_proyecto AND fase_codigo='final' AND iniciada_en IS NOT NULL AND finalizada_en IS NULL;
 IF p.estado IS DISTINCT FROM 'activo' OR fase_id IS NULL OR p.informe_aprobado_comite_en IS NULL THEN
  RETURN QUERY SELECT false,'La fase Final no está disponible para registrar datos.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_valor IS NULL OR length(btrim(p_valor))=0 OR length(p_valor)>8000 OR (p_campo<>'licencia' AND btrim(p_valor)!~* '^https?://[^[:space:]]+$') THEN
  RETURN QUERY SELECT false,'Completa el valor; los enlaces deben comenzar por http:// o https://.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO entrega_final(proyecto_id) VALUES(p_proyecto) ON CONFLICT DO NOTHING;
 IF p_campo='licencia' THEN
  SELECT tipo_licencia INTO anterior FROM entrega_final WHERE proyecto_id=p_proyecto;
  UPDATE entrega_final SET tipo_licencia=btrim(p_valor) WHERE proyecto_id=p_proyecto;
 ELSIF p_campo='repositorio' THEN
  SELECT repositorio_url INTO anterior FROM entrega_final WHERE proyecto_id=p_proyecto;
  UPDATE entrega_final SET repositorio_url=btrim(p_valor),repositorio_registrado_por=actor.id,repositorio_registrado_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto;
 ELSE
  INSERT INTO documento(proyecto_id,proyecto_fase_id,tipo_codigo) VALUES(p_proyecto,fase_id,p_campo)
   ON CONFLICT(proyecto_fase_id,tipo_codigo,etiqueta) DO UPDATE SET etiqueta=excluded.etiqueta RETURNING id INTO doc;
  SELECT url INTO anterior FROM documento_version WHERE documento_id=doc ORDER BY numero DESC LIMIT 1;
  INSERT INTO documento_version(documento_id,numero,url,registrado_por)
   SELECT doc,coalesce(max(v.numero),0)+1,btrim(p_valor),actor.id FROM documento_version v WHERE v.documento_id=doc RETURNING id INTO version;
 END IF;
 PERFORM avisar_proyecto(p_proyecto,actor.id,'guardar_entregable_final','proyecto',p_proyecto,'Entregable final actualizado',
  replace(p_campo,'_',' ')||': '||btrim(p_valor)||CASE WHEN anterior IS NOT NULL THEN E'\nValor anterior: '||anterior ELSE '' END);
 RETURN QUERY SELECT true,'Dato final guardado con historial.'::text,p_proyecto;
END; $$;

CREATE OR REPLACE FUNCTION grado.finalizar_proyecto(p_token text,p_proyecto bigint,p_nota text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN RETURN QUERY SELECT false,'Solo el Comité puede finalizar el proyecto.'::text,NULL::bigint; RETURN; END IF;
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
 IF p.estado IS DISTINCT FROM 'activo' OR p.informe_aprobado_comite_en IS NULL OR NOT EXISTS(
  SELECT 1 FROM proyecto_fase WHERE proyecto_id=p_proyecto AND fase_codigo='final' AND iniciada_en IS NOT NULL AND finalizada_en IS NULL) THEN
  RETURN QUERY SELECT false,'El cierre requiere un proyecto activo en fase Final con informe aprobado.'::text,NULL::bigint; RETURN;
 END IF;
 PERFORM avisar_proyecto(p_proyecto,actor.id,'finalizar_proyecto','proyecto',p_proyecto,'Proyecto finalizado',coalesce(nullif(btrim(p_nota),''),'Cierre aprobado por el Comité.'));
 UPDATE proyecto_fase SET estado='aprobado',finalizada_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto AND fase_codigo='final';
 UPDATE proyecto SET estado='finalizado',finalizado_por=actor.id,finalizado_en=CURRENT_TIMESTAMP WHERE id=p_proyecto;
 UPDATE participante_proyecto SET retiro_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto AND retiro_en IS NULL;
 UPDATE asignacion_proyecto SET fin_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto AND fin_en IS NULL;
 RETURN QUERY SELECT true,'Proyecto finalizado. Sus datos y documentos quedan disponibles para consulta.'::text,p_proyecto;
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
REVOKE ALL ON FUNCTION grado.cerrar_solicitudes_pendientes(bigint,bigint,text,bigint),grado.cerrar_tramites_proyecto(),
 grado.guardar_entregable_final(text,bigint,text,text),grado.finalizar_proyecto(text,bigint,text),
 grado.crear_solicitud(text,bigint,text,text,bigint),grado.decidir_solicitud(text,bigint,text,text) FROM PUBLIC;
COMMIT;
