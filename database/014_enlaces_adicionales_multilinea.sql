-- Correccion aditiva: los textarea HTML envian CRLF y pueden contener lineas vacias.
-- Reemplaza solo las dos funciones de envio; conserva datos, firmas y permisos.
BEGIN;

CREATE OR REPLACE FUNCTION grado.presentar_pago(p_token text,p_proyecto bigint,p_comprobante text,p_adicionales text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, pg_temp AS $$
DECLARE actor record; proyecto_actual record; fase_id bigint; entrega bigint; doc bigint; version bigint;
 enlace text; enlaces text[]; posicion int:=0; tipo text; etiqueta_doc text; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT * INTO proyecto_actual FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF actor.id IS NULL OR actor.rol_codigo<>'estudiante' OR proyecto_actual.estado IS DISTINCT FROM 'activo'
 OR NOT EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=actor.id AND retiro_en IS NULL) THEN
  RETURN QUERY SELECT false,'No puedes presentar documentos en este proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT id INTO fase_id FROM proyecto_fase WHERE proyecto_id=p_proyecto AND fase_codigo='pago' AND finalizada_en IS NULL;
 IF fase_id IS NULL OR EXISTS(SELECT 1 FROM datos_pago WHERE proyecto_id=p_proyecto AND aprobado_en IS NOT NULL) THEN
  RETURN QUERY SELECT false,'El pago ya fue aprobado o esta fase terminó.'::text,NULL::bigint; RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM ciclo_revision c JOIN entrega_revision e ON e.id=c.entrega_id WHERE e.fase_origen_id=fase_id AND c.finalizado_en IS NULL) THEN
  RETURN QUERY SELECT false,'Tu conjunto de documentos ya está en revisión.'::text,NULL::bigint; RETURN;
 END IF;
 enlaces:=ARRAY[btrim(coalesce(p_comprobante,''))]||ARRAY(SELECT btrim(x,E' \t') FROM regexp_split_to_table(coalesce(p_adicionales,''),E'[\r\n]+') x WHERE btrim(x,E' \t')<>'');
 FOREACH enlace IN ARRAY enlaces LOOP
  IF enlace !~* '^https?://[^[:space:]]+$' THEN
   RETURN QUERY SELECT false,'Escribe enlaces web válidos que comiencen por http:// o https://.'::text,NULL::bigint; RETURN;
  END IF;
 END LOOP;
 INSERT INTO entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por)
 SELECT p_proyecto,fase_id,coalesce(max(e.numero),0)+1,actor.id FROM entrega_revision e WHERE e.fase_origen_id=fase_id RETURNING id INTO entrega;
 FOREACH enlace IN ARRAY enlaces LOOP
  tipo:=CASE WHEN posicion=0 THEN 'comprobante_pago' ELSE 'adicional' END;
  etiqueta_doc:=CASE WHEN posicion=0 THEN '' ELSE 'Documento adicional '||posicion END;
  INSERT INTO documento(proyecto_id,proyecto_fase_id,tipo_codigo,etiqueta) VALUES(p_proyecto,fase_id,tipo,etiqueta_doc)
   ON CONFLICT(proyecto_fase_id,tipo_codigo,etiqueta) DO UPDATE SET etiqueta=excluded.etiqueta RETURNING id INTO doc;
  INSERT INTO documento_version(documento_id,numero,url,registrado_por)
   SELECT doc,coalesce(max(v.numero),0)+1,enlace,actor.id FROM documento_version v WHERE v.documento_id=doc RETURNING id INTO version;
  INSERT INTO entrega_documento_version(entrega_id,proyecto_id,documento_id,version_id) VALUES(entrega,p_proyecto,doc,version);
  posicion:=posicion+1;
 END LOOP;
 INSERT INTO ciclo_revision(entrega_id,numero) VALUES(entrega,1);
 UPDATE plazo_correccion pc SET entrega_reenvio_id=entrega FROM revision_entrega r JOIN ciclo_revision c ON c.id=r.ciclo_id JOIN entrega_revision e ON e.id=c.entrega_id
 WHERE pc.revision_id=r.id AND e.fase_origen_id=fase_id AND pc.entrega_reenvio_id IS NULL;
 UPDATE proyecto_fase SET estado=NULL WHERE id=fase_id;
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id) VALUES(p_proyecto,actor.id,'usuario','presentar_pago','entrega_revision',entrega) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) SELECT evento,u.id,'Pago pendiente de revisión',proyecto_actual.titulo FROM usuario u WHERE u.rol_codigo='comite' AND u.estado='activo';
 RETURN QUERY SELECT true,'Conjunto enviado al Comité.'::text,p_proyecto;
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

COMMIT;
