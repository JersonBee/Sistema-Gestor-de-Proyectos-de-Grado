-- Flujo Propuesta/Informe, pausas y procesamiento idempotente de plazos.
-- No configura todavía el programador; 009_cron.sql lo instala en Supabase.
BEGIN;
ALTER TABLE grado.revision_entrega ALTER COLUMN responsable_id DROP NOT NULL;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='grado.revision_entrega'::regclass AND conname='revision_responsable_docente') THEN
  ALTER TABLE grado.revision_entrega ADD CONSTRAINT revision_responsable_docente CHECK(etapa='comite' OR responsable_id IS NOT NULL);
 END IF;
END; $$;
CREATE UNIQUE INDEX IF NOT EXISTS revision_una_pendiente_por_ciclo ON grado.revision_entrega(ciclo_id) WHERE decision IS NULL;
ALTER TABLE grado.plazo_correccion ADD COLUMN IF NOT EXISTS alertada_en timestamptz;
ALTER TABLE grado.proyecto ADD COLUMN IF NOT EXISTS aviso_informe_habilitado_en timestamptz;

-- La lectura histórica permanece para docentes que estuvieron asignados.
-- Cada escritura exige además la asignación vigente en su operación específica.
CREATE OR REPLACE FUNCTION grado.puede_consultar_proyecto(p_usuario bigint,p_proyecto bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=grado,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM usuario u WHERE u.id=p_usuario AND u.estado='activo' AND (
  u.rol_codigo IN('comite','secretaria') OR
  (u.rol_codigo='estudiante' AND EXISTS(SELECT 1 FROM participante_proyecto pp WHERE pp.proyecto_id=p_proyecto AND pp.estudiante_id=u.id)) OR
  (u.rol_codigo IN('director','evaluador') AND EXISTS(SELECT 1 FROM asignacion_proyecto ap WHERE ap.proyecto_id=p_proyecto AND ap.docente_id=u.id))));
$$;

CREATE OR REPLACE FUNCTION grado.avisar_proyecto(p_proyecto bigint,p_actor bigint,p_accion text,p_entidad text,p_id bigint,p_asunto text,p_cuerpo text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE evento bigint;
BEGIN
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,p_actor,CASE WHEN p_actor IS NULL THEN 'sistema' ELSE 'usuario' END,p_accion,p_entidad,p_id,jsonb_build_object('detalle',p_cuerpo)) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo)
 SELECT evento,id,p_asunto,p_cuerpo FROM (
  SELECT estudiante_id AS id FROM participante_proyecto WHERE proyecto_id=p_proyecto AND retiro_en IS NULL
  UNION SELECT docente_id FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND fin_en IS NULL
  UNION SELECT id FROM usuario WHERE rol_codigo='comite' AND estado='activo'
 ) destinatarios;
 RETURN evento;
END; $$;

-- Helper interno: el llamador ya bloqueó el proyecto y validó al actor.
CREATE OR REPLACE FUNCTION grado.devolver_revision(p_revision bigint,p_resultado text,p_reporte text,p_actor bigint,p_ahora timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE r record; segunda text;
BEGIN
 SELECT re.id,re.ciclo_id,e.proyecto_id,e.fase_origen_id,f.fase_codigo INTO r FROM revision_entrega re
 JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id JOIN proyecto_fase f ON f.id=e.fase_origen_id
 WHERE re.id=p_revision AND re.decision IS NULL AND c.finalizado_en IS NULL;
 IF r.id IS NULL THEN RETURN; END IF;
 segunda:=CASE WHEN r.fase_codigo='propuesta_1' THEN 'propuesta_2' ELSE 'informe_2' END;
 UPDATE revision_entrega SET decision=p_resultado,reporte_respuesta=p_reporte,decidida_en=p_ahora,
  responsable_id=coalesce(p_actor,responsable_id) WHERE id=p_revision;
 UPDATE ciclo_revision SET finalizado_en=p_ahora WHERE id=r.ciclo_id;
 UPDATE proyecto_fase SET estado=p_resultado,finalizada_en=p_ahora WHERE proyecto_id=r.proyecto_id AND fase_codigo=segunda AND iniciada_en IS NOT NULL AND finalizada_en IS NULL;
 UPDATE proyecto_fase SET estado=p_resultado,finalizada_en=NULL WHERE id=r.fase_origen_id;
 IF p_resultado='rechazado' THEN
  INSERT INTO plazo_correccion(revision_id,inicio_en,limite_en) VALUES(p_revision,p_ahora,limite_dias_calendario(p_ahora,3));
 END IF;
 PERFORM avisar_proyecto(r.proyecto_id,p_actor,'devolver_revision','revision_entrega',p_revision,
  CASE WHEN p_resultado='aplicado' THEN 'Venció el plazo de revisión' ELSE 'Se requieren correcciones' END,
  p_reporte||E'\nEl estudiante debe reenviar el conjunto completo a su director.');
END; $$;

CREATE OR REPLACE FUNCTION grado.procesar_plazos_proyecto(p_proyecto bigint,p_ahora timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE p record; r record; pc record;
BEGIN
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF p.estado IS DISTINCT FROM 'activo' THEN RETURN; END IF;
 IF p.informe_aprobado_comite_en IS NULL AND p.vence_en IS NOT NULL AND p.vence_en<=p_ahora THEN
  PERFORM avisar_proyecto(p.id,NULL,'cancelar_por_vencimiento','proyecto',p.id,'Proyecto cancelado por vencimiento',
   'Se cumplieron los 180 días de vigencia de Informe I. La idea vuelve al banco.');
  UPDATE revision_entrega re SET decision='aplicado',decidida_en=p_ahora,reporte_respuesta='Proyecto cancelado por vencimiento.'
   FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id WHERE re.ciclo_id=c.id AND e.proyecto_id=p.id AND re.decision IS NULL;
  UPDATE ciclo_revision c SET finalizado_en=p_ahora FROM entrega_revision e WHERE e.id=c.entrega_id AND e.proyecto_id=p.id AND c.finalizado_en IS NULL;
  UPDATE proyecto_fase SET estado=coalesce(estado,'aplicado'),finalizada_en=p_ahora WHERE proyecto_id=p.id AND iniciada_en IS NOT NULL AND finalizada_en IS NULL;
  UPDATE participante_proyecto SET retiro_en=p_ahora WHERE proyecto_id=p.id AND retiro_en IS NULL;
  UPDATE asignacion_proyecto SET fin_en=p_ahora WHERE proyecto_id=p.id AND fin_en IS NULL;
  UPDATE proyecto SET estado='cancelado' WHERE id=p.id;
  RETURN;
 END IF;
 FOR r IN SELECT re.id FROM revision_entrega re JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id
  WHERE e.proyecto_id=p.id AND c.finalizado_en IS NULL AND re.decision IS NULL AND re.etapa IN('director','evaluador') AND re.limite_en<=p_ahora
 LOOP
  PERFORM devolver_revision(r.id,'aplicado','El docente no registró su revisión dentro de cinco días calendario.',NULL,p_ahora);
 END LOOP;
 FOR pc IN SELECT cor.id FROM plazo_correccion cor JOIN revision_entrega re ON re.id=cor.revision_id
  JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id
  WHERE e.proyecto_id=p.id AND cor.entrega_reenvio_id IS NULL AND cor.alertada_en IS NULL AND cor.limite_en<=p_ahora
 LOOP
  PERFORM avisar_proyecto(p.id,NULL,'alertar_correccion','plazo_correccion',pc.id,'Terminó el plazo de corrección',
   'Han pasado tres días calendario. Todavía puedes reenviar el conjunto completo de documentos.');
  UPDATE plazo_correccion SET alertada_en=p_ahora WHERE id=pc.id;
 END LOOP;
 IF p.informe_habilitado_en IS NOT NULL AND p.informe_habilitado_en<=p_ahora AND p.aviso_informe_habilitado_en IS NULL AND p.informe_aprobado_comite_en IS NULL THEN
  PERFORM avisar_proyecto(p.id,NULL,'habilitar_informe','proyecto',p.id,'Ya puedes presentar Informe I',
   'Se completó la espera de 90 días. Puedes enviar F-DC-125, F-DC-129 y Turnitin a tu director.');
  UPDATE proyecto SET aviso_informe_habilitado_en=p_ahora WHERE id=p.id;
 END IF;
END; $$;

CREATE OR REPLACE FUNCTION grado.procesar_plazos(p_ahora timestamptz DEFAULT CURRENT_TIMESTAMP)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE p record; cantidad integer:=0;
BEGIN
 IF NOT pg_try_advisory_xact_lock(740018) THEN RETURN 0; END IF;
 FOR p IN SELECT id FROM proyecto WHERE estado='activo' ORDER BY id FOR UPDATE SKIP LOCKED LOOP
  PERFORM procesar_plazos_proyecto(p.id,p_ahora); cantidad:=cantidad+1;
 END LOOP;
 RETURN cantidad;
END; $$;

CREATE OR REPLACE FUNCTION grado.presentar_documentos(p_token text,p_proyecto bigint,p_tipo text,p_documentos jsonb,p_adicionales text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; origen text; fase_id bigint; director bigint; entrega bigint; ciclo bigint; doc bigint; version bigint;
 codigo text; requeridos text[]; enlace text; adicionales text[]; indice integer:=0; etiqueta_doc text; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF actor.id IS NULL OR actor.rol_codigo<>'estudiante' OR NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=actor.id AND retiro_en IS NULL) THEN
  RETURN QUERY SELECT false,'No puedes presentar documentos en este proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
 IF p.estado IS DISTINCT FROM 'activo' OR p_tipo IS NULL OR p_tipo NOT IN('propuesta','informe') THEN
  RETURN QUERY SELECT false,'El proyecto no admite este trámite.'::text,NULL::bigint; RETURN;
 END IF;
 origen:=CASE WHEN p_tipo='propuesta' THEN 'propuesta_1' ELSE 'informe_1' END;
 SELECT id INTO fase_id FROM proyecto_fase WHERE proyecto_id=p.id AND fase_codigo=origen AND iniciada_en IS NOT NULL AND finalizada_en IS NULL;
 IF fase_id IS NULL THEN RETURN QUERY SELECT false,'Esta fase no está disponible para enviar documentos.'::text,NULL::bigint; RETURN; END IF;
 IF p_tipo='informe' AND (p.informe_habilitado_en IS NULL OR CURRENT_TIMESTAMP<p.informe_habilitado_en) THEN
  RETURN QUERY SELECT false,'Aún no se han cumplido los 90 días para presentar Informe I.'::text,NULL::bigint; RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id WHERE e.fase_origen_id=fase_id AND c.finalizado_en IS NULL) THEN
  RETURN QUERY SELECT false,'El conjunto ya está en revisión.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT ap.docente_id INTO director FROM asignacion_proyecto ap JOIN usuario u ON u.id=ap.docente_id WHERE ap.proyecto_id=p.id AND ap.funcion='director' AND ap.fin_en IS NULL AND u.estado='activo' AND u.rol_codigo='director';
 IF director IS NULL OR NOT EXISTS(SELECT 1 FROM asignacion_proyecto ap JOIN usuario u ON u.id=ap.docente_id WHERE ap.proyecto_id=p.id AND ap.funcion='evaluador' AND ap.fin_en IS NULL AND u.estado='activo' AND u.rol_codigo='evaluador') THEN
  RETURN QUERY SELECT false,'El proyecto necesita director y evaluador activos.'::text,NULL::bigint; RETURN;
 END IF;
 requeridos:=CASE WHEN p_tipo='propuesta' THEN ARRAY['f_dc_124','turnitin'] ELSE ARRAY['f_dc_125','f_dc_129','turnitin'] END;
 FOREACH codigo IN ARRAY requeridos LOOP
  IF coalesce(btrim(p_documentos->>codigo),'') !~* '^https?://[^[:space:]]+$' THEN
   RETURN QUERY SELECT false,'Presenta todos los formatos y Turnitin mediante enlaces http:// o https://.'::text,NULL::bigint; RETURN;
  END IF;
 END LOOP;
 adicionales:=ARRAY(SELECT btrim(x,E' \t') FROM regexp_split_to_table(coalesce(p_adicionales,''),E'[\r\n]+') x WHERE btrim(x,E' \t')<>'');
 FOREACH enlace IN ARRAY adicionales LOOP
  IF enlace !~* '^https?://[^[:space:]]+$' THEN RETURN QUERY SELECT false,'Revisa los enlaces adicionales.'::text,NULL::bigint; RETURN; END IF;
 END LOOP;
 INSERT INTO entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por)
 SELECT p.id,fase_id,coalesce(max(e.numero),0)+1,actor.id FROM entrega_revision e WHERE e.fase_origen_id=fase_id RETURNING id INTO entrega;
 FOREACH codigo IN ARRAY requeridos||ARRAY(SELECT 'adicional' FROM unnest(adicionales)) LOOP
  IF codigo='adicional' THEN indice:=indice+1; enlace:=adicionales[indice]; etiqueta_doc:='Documento adicional '||indice;
  ELSE enlace:=btrim(p_documentos->>codigo); etiqueta_doc:=''; END IF;
  INSERT INTO documento(proyecto_id,proyecto_fase_id,tipo_codigo,etiqueta) VALUES(p.id,fase_id,codigo,etiqueta_doc)
   ON CONFLICT(proyecto_fase_id,tipo_codigo,etiqueta) DO UPDATE SET etiqueta=excluded.etiqueta RETURNING id INTO doc;
  INSERT INTO documento_version(documento_id,numero,url,registrado_por)
   SELECT doc,coalesce(max(v.numero),0)+1,enlace,actor.id FROM documento_version v WHERE v.documento_id=doc RETURNING id INTO version;
  INSERT INTO entrega_documento_version(entrega_id,proyecto_id,documento_id,version_id) VALUES(entrega,p.id,doc,version);
 END LOOP;
 INSERT INTO ciclo_revision(entrega_id,numero) VALUES(entrega,1) RETURNING id INTO ciclo;
 INSERT INTO revision_entrega(ciclo_id,etapa,responsable_id,limite_en) VALUES(ciclo,'director',director,limite_dias_calendario(CURRENT_TIMESTAMP,5));
 UPDATE plazo_correccion pc SET entrega_reenvio_id=entrega FROM revision_entrega r JOIN ciclo_revision c ON c.id=r.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id
  WHERE pc.revision_id=r.id AND e.fase_origen_id=fase_id AND pc.entrega_reenvio_id IS NULL;
 UPDATE proyecto_fase SET estado=NULL WHERE id=fase_id;
 PERFORM avisar_proyecto(p.id,actor.id,'presentar_documentos','entrega_revision',entrega,'Nueva entrega para el director','El estudiante presentó el conjunto completo de '||p_tipo||'.');
 RETURN QUERY SELECT true,'Conjunto enviado al director.'::text,p.id;
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

CREATE OR REPLACE FUNCTION grado.cambiar_pausa(p_token text,p_proyecto bigint,p_pausar boolean,p_motivo text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; pausa record; dias integer;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' OR p_pausar IS NULL THEN RETURN QUERY SELECT false,'Solo el Comité puede pausar o reanudar un proyecto.'::text,NULL::bigint; RETURN; END IF;
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF p_pausar THEN
  PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
  SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
  IF p.estado IS DISTINCT FROM 'activo' OR nullif(btrim(p_motivo),'') IS NULL THEN RETURN QUERY SELECT false,'Indica un motivo y selecciona un proyecto activo.'::text,NULL::bigint; RETURN; END IF;
  INSERT INTO pausa_proyecto(proyecto_id,pausado_por,motivo) VALUES(p.id,actor.id,btrim(p_motivo));
  UPDATE proyecto SET estado='desactivado',motivo_desactivacion=btrim(p_motivo) WHERE id=p.id;
 ELSE
  SELECT * INTO pausa FROM pausa_proyecto WHERE proyecto_id=p_proyecto AND fin_en IS NULL;
  IF p.estado IS DISTINCT FROM 'desactivado' OR pausa.id IS NULL THEN RETURN QUERY SELECT false,'El proyecto no tiene una pausa abierta.'::text,NULL::bigint; RETURN; END IF;
  -- Cada día o fracción de pausa se repone como día calendario completo.
  dias:=greatest(1,ceil(extract(epoch FROM (CURRENT_TIMESTAMP-pausa.inicio_en))/86400)::integer);
  UPDATE proyecto SET estado='activo',motivo_desactivacion=NULL,
   informe_habilitado_en=CASE WHEN informe_habilitado_en>pausa.inicio_en THEN informe_habilitado_en+make_interval(days=>dias) ELSE informe_habilitado_en END,
   vence_en=CASE WHEN vence_en>pausa.inicio_en THEN vence_en+make_interval(days=>dias) ELSE vence_en END WHERE id=p.id;
  UPDATE revision_entrega re SET limite_en=re.limite_en+make_interval(days=>dias) FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id
   WHERE re.ciclo_id=c.id AND e.proyecto_id=p.id AND re.decision IS NULL AND re.limite_en>pausa.inicio_en;
  UPDATE plazo_correccion pc SET limite_en=pc.limite_en+make_interval(days=>dias) FROM revision_entrega re JOIN ciclo_revision c ON c.id=re.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id
   WHERE pc.revision_id=re.id AND e.proyecto_id=p.id AND pc.entrega_reenvio_id IS NULL AND pc.limite_en>pausa.inicio_en;
  UPDATE pausa_proyecto SET reanudado_por=actor.id,fin_en=CURRENT_TIMESTAMP WHERE id=pausa.id;
 END IF;
 PERFORM avisar_proyecto(p.id,actor.id,CASE WHEN p_pausar THEN 'pausar_proyecto' ELSE 'reanudar_proyecto' END,'proyecto',p.id,
  CASE WHEN p_pausar THEN 'Proyecto en pausa' ELSE 'Proyecto reanudado' END,
  CASE WHEN p_pausar THEN btrim(p_motivo) ELSE 'Se repusieron '||dias||' días calendario a los plazos pendientes.' END);
 RETURN QUERY SELECT true,CASE WHEN p_pausar THEN 'Proyecto pausado. Los trámites y plazos están detenidos.' ELSE 'Proyecto reanudado con sus plazos ajustados.' END,p.id;
END; $$;

REVOKE ALL ON FUNCTION grado.avisar_proyecto(bigint,bigint,text,text,bigint,text,text),
 grado.devolver_revision(bigint,text,text,bigint,timestamptz),grado.procesar_plazos_proyecto(bigint,timestamptz),
 grado.procesar_plazos(timestamptz),grado.presentar_documentos(text,bigint,text,jsonb,text),
 grado.decidir_revision(text,bigint,text,text),grado.cambiar_pausa(text,bigint,boolean,text) FROM PUBLIC;
COMMIT;
