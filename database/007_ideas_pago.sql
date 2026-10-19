-- Migración aditiva: banco de ideas, Pago y asignación posterior a su aprobación.
BEGIN;

CREATE OR REPLACE FUNCTION grado.puede_consultar_idea(p_usuario bigint, p_idea bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = grado, pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM idea i JOIN usuario u ON u.id=p_usuario
 WHERE i.id=p_idea AND u.estado='activo' AND
 (i.estado='aprobada' OR i.autor_id=u.id OR u.rol_codigo='comite'));
$$;

CREATE OR REPLACE FUNCTION grado.proponer_idea(p_token text, p_datos jsonb)
RETURNS TABLE(ok boolean, mensaje text, recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, extensions, pg_temp AS $$
DECLARE actor record; nueva bigint; area bigint; linea bigint; campo text;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo NOT IN ('estudiante','director') THEN
  RETURN QUERY SELECT false,'No tienes permiso para proponer ideas.'::text,NULL::bigint; RETURN;
 END IF;
 FOREACH campo IN ARRAY ARRAY['titulo','descripcion','objetivos','tecnologias','area','linea','modalidad'] LOOP
  IF nullif(btrim(p_datos->>campo),'') IS NULL THEN
   RETURN QUERY SELECT false,'Completa todos los campos de la idea.'::text,NULL::bigint; RETURN;
  END IF;
 END LOOP;
 IF length(p_datos->>'titulo')>250 OR length(p_datos::text)>64000 THEN
  RETURN QUERY SELECT false,'El contenido es demasiado largo.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO area_experiencia(nombre) VALUES(btrim(p_datos->>'area')) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO area;
 INSERT INTO linea_investigacion(nombre) VALUES(btrim(p_datos->>'linea')) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO linea;
 INSERT INTO idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias)
 VALUES(actor.id,(p_datos->>'modalidad')::bigint,area,linea,btrim(p_datos->>'titulo'),btrim(p_datos->>'descripcion'),btrim(p_datos->>'objetivos'),btrim(p_datos->>'tecnologias')) RETURNING id INTO nueva;
 INSERT INTO evento_auditoria(actor_id,origen,accion,entidad,entidad_id) VALUES(actor.id,'usuario','proponer_idea','idea',nueva);
 RETURN QUERY SELECT true,'Idea enviada al Comité para su revisión.'::text,nueva;
EXCEPTION WHEN foreign_key_violation OR invalid_text_representation THEN
 RETURN QUERY SELECT false,'Revisa la modalidad seleccionada.'::text,NULL::bigint;
END; $$;

CREATE OR REPLACE FUNCTION grado.decidir_idea(p_token text,p_idea bigint,p_decision text,p_reporte text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, pg_temp AS $$
DECLARE actor record; propuesta record; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN
  RETURN QUERY SELECT false,'Solo el Comité puede decidir sobre ideas.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT * INTO propuesta FROM idea WHERE id=p_idea FOR UPDATE;
 IF propuesta.id IS NULL OR propuesta.estado<>'pendiente' THEN
  RETURN QUERY SELECT false,'Esta idea ya fue revisada o no existe.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('aprobada','rechazada') OR nullif(btrim(p_reporte),'') IS NULL THEN
  RETURN QUERY SELECT false,'Selecciona una decisión y escribe sus observaciones.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO decision_idea(idea_id,responsable_id,decision,observaciones) VALUES(p_idea,actor.id,p_decision,btrim(p_reporte));
 UPDATE idea SET estado=p_decision WHERE id=p_idea;
 INSERT INTO evento_auditoria(actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(actor.id,'usuario','decidir_idea','idea',p_idea,jsonb_build_object('decision',p_decision,'reporte',btrim(p_reporte))) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,propuesta.autor_id,'Tu idea fue revisada',p_decision||': '||btrim(p_reporte));
 RETURN QUERY SELECT true,'La decisión quedó registrada.'::text,p_idea;
END; $$;

CREATE OR REPLACE FUNCTION grado.crear_proyecto(p_token text,p_idea bigint,p_datos jsonb)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, pg_temp AS $$
DECLARE actor record; propuesta record; nuevo bigint; integrante record; pareja bigint; preferido bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'estudiante' THEN
  RETURN QUERY SELECT false,'Solo estudiantes pueden iniciar un proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT * INTO propuesta FROM idea WHERE id=p_idea FOR UPDATE;
 IF propuesta.id IS NULL OR propuesta.estado<>'aprobada' OR EXISTS(SELECT 1 FROM proyecto WHERE idea_id=p_idea AND estado<>'cancelado') THEN
  RETURN QUERY SELECT false,'La idea debe estar aprobada y disponible.'::text,NULL::bigint; RETURN;
 END IF;
 IF nullif(btrim(p_datos->>'nombre'),'') IS NULL THEN
  RETURN QUERY SELECT false,'Completa tus datos de participante.'::text,NULL::bigint; RETURN;
 END IF;
 IF nullif(btrim(p_datos->>'pareja_correo'),'') IS NOT NULL THEN
  SELECT id INTO pareja FROM usuario WHERE lower(correo)=lower(btrim(p_datos->>'pareja_correo')) AND rol_codigo='estudiante' AND estado='activo';
  IF pareja IS NULL OR pareja=actor.id OR nullif(btrim(p_datos->>'pareja_nombre'),'') IS NULL THEN
   RETURN QUERY SELECT false,'El segundo integrante debe tener una cuenta estudiantil activa y datos completos.'::text,NULL::bigint; RETURN;
  END IF;
 END IF;
 -- Bloqueo ordenado: dos proyectos no pueden tomar simultáneamente un integrante.
 PERFORM id FROM usuario WHERE id IN(actor.id,pareja) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM participante_proyecto WHERE estudiante_id IN(actor.id,pareja) AND retiro_en IS NULL) THEN
  RETURN QUERY SELECT false,'Uno de los integrantes ya pertenece a un proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 preferido:=nullif(p_datos->>'director','')::bigint;
 IF preferido IS NOT NULL AND NOT EXISTS(SELECT 1 FROM docente_apto_idea a JOIN usuario u ON u.id=a.docente_id WHERE a.idea_id=p_idea AND a.docente_id=preferido AND u.rol_codigo='director') THEN
  RETURN QUERY SELECT false,'Selecciona un director que coincida con la idea.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por)
 VALUES(p_idea,propuesta.modalidad_id,propuesta.titulo,propuesta.objetivos,propuesta.descripcion,actor.id) RETURNING id INTO nuevo;
 INSERT INTO participante_proyecto(proyecto_id,estudiante_id,nombre_en_pago,correo_en_pago,documento_en_pago,telefono_en_pago,plaza)
 VALUES(nuevo,actor.id,btrim(p_datos->>'nombre'),actor.correo,nullif(btrim(p_datos->>'documento'),''),nullif(btrim(p_datos->>'telefono'),''),1);
 IF pareja IS NOT NULL THEN
  INSERT INTO participante_proyecto(proyecto_id,estudiante_id,nombre_en_pago,correo_en_pago,documento_en_pago,telefono_en_pago,plaza)
  SELECT nuevo,pareja,btrim(p_datos->>'pareja_nombre'),u.correo,nullif(btrim(p_datos->>'pareja_documento'),''),nullif(btrim(p_datos->>'pareja_telefono'),''),2 FROM usuario u WHERE u.id=pareja;
 END IF;
 INSERT INTO datos_pago(proyecto_id,director_propuesto_id) VALUES(nuevo,preferido);
 INSERT INTO proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(nuevo,'pago',CURRENT_TIMESTAMP);
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id) VALUES(nuevo,actor.id,'usuario','crear_proyecto','proyecto',nuevo);
 RETURN QUERY SELECT true,'Idea reservada. Ya puedes presentar el comprobante de pago.'::text,nuevo;
EXCEPTION WHEN unique_violation THEN
 RETURN QUERY SELECT false,'La idea o un integrante ya fue reservado por otro proyecto.'::text,NULL::bigint;
 WHEN invalid_text_representation OR foreign_key_violation THEN
 RETURN QUERY SELECT false,'Revisa los datos del proyecto.'::text,NULL::bigint;
END; $$;

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
 IF p_decision IS NULL OR p_decision NOT IN ('aprobado','rechazado') OR nullif(btrim(p_reporte),'') IS NULL THEN
  RETURN QUERY SELECT false,'Selecciona una decisión y escribe el reporte para el estudiante.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO revision_entrega(ciclo_id,etapa,responsable_id,decision,reporte_respuesta,decidida_en)
 VALUES(ciclo,'comite',actor.id,p_decision,btrim(p_reporte),CURRENT_TIMESTAMP) RETURNING id INTO revision;
 UPDATE ciclo_revision SET finalizado_en=CURRENT_TIMESTAMP WHERE id=ciclo;
 UPDATE proyecto_fase SET estado=p_decision WHERE proyecto_id=p_proyecto AND fase_codigo='pago';
 IF p_decision='aprobado' THEN
  UPDATE datos_pago SET aprobado_por=actor.id,aprobado_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto;
 ELSE
  INSERT INTO plazo_correccion(revision_id,inicio_en,limite_en) VALUES(revision,CURRENT_TIMESTAMP,limite_dias_calendario(CURRENT_TIMESTAMP,3));
 END IF;
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,actor.id,'usuario','decidir_pago','revision_entrega',revision,jsonb_build_object('decision',p_decision,'reporte',btrim(p_reporte))) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo)
 SELECT evento,pp.estudiante_id,'El Comité revisó el pago',p_decision||': '||btrim(p_reporte) FROM participante_proyecto pp WHERE pp.proyecto_id=p_proyecto AND pp.retiro_en IS NULL;
 RETURN QUERY SELECT true,'Decisión guardada sobre el conjunto completo.'::text,p_proyecto;
END; $$;

CREATE OR REPLACE FUNCTION grado.asignar_docentes(p_token text,p_proyecto bigint,p_director bigint,p_evaluador bigint)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, pg_temp AS $$
DECLARE actor record; proyecto_actual record; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN
  RETURN QUERY SELECT false,'Solo el Comité puede asignar docentes.'::text,NULL::bigint; RETURN;
 END IF;
 SELECT * INTO proyecto_actual FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF proyecto_actual.estado IS DISTINCT FROM 'activo' OR NOT EXISTS(SELECT 1 FROM datos_pago WHERE proyecto_id=p_proyecto AND aprobado_en IS NOT NULL)
 OR NOT EXISTS(SELECT 1 FROM proyecto_fase WHERE proyecto_id=p_proyecto AND fase_codigo='pago' AND finalizada_en IS NULL) THEN
  RETURN QUERY SELECT false,'Primero debe aprobarse el pago y la idea.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_director IS NULL OR p_evaluador IS NULL OR p_director=p_evaluador
 OR NOT EXISTS(SELECT 1 FROM docente_apto_idea a JOIN usuario u ON u.id=a.docente_id WHERE a.idea_id=proyecto_actual.idea_id AND a.docente_id=p_director AND u.rol_codigo='director')
 OR NOT EXISTS(SELECT 1 FROM docente_apto_idea a JOIN usuario u ON u.id=a.docente_id WHERE a.idea_id=proyecto_actual.idea_id AND a.docente_id=p_evaluador AND u.rol_codigo='evaluador') THEN
  RETURN QUERY SELECT false,'Selecciona director y evaluador distintos que coincidan en modalidad, área y línea.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO asignacion_proyecto(proyecto_id,docente_id,funcion,asignado_por) VALUES(p_proyecto,p_director,'director',actor.id),(p_proyecto,p_evaluador,'evaluador',actor.id);
 UPDATE proyecto_fase SET finalizada_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto AND fase_codigo='pago';
 INSERT INTO proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(p_proyecto,'propuesta_1',CURRENT_TIMESTAMP);
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,actor.id,'usuario','asignar_docentes','proyecto',p_proyecto,jsonb_build_object('director',p_director,'evaluador',p_evaluador)) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo)
 SELECT evento,id,'Tu proyecto inicia Propuesta I',proyecto_actual.titulo FROM usuario WHERE id IN(p_director,p_evaluador)
 UNION SELECT evento,estudiante_id,'Tu proyecto inicia Propuesta I',proyecto_actual.titulo FROM participante_proyecto WHERE proyecto_id=p_proyecto AND retiro_en IS NULL;
 RETURN QUERY SELECT true,'Docentes asignados. El proyecto avanzó a Propuesta I.'::text,p_proyecto;
EXCEPTION WHEN unique_violation THEN RETURN QUERY SELECT false,'El proyecto ya tiene docentes asignados.'::text,NULL::bigint;
END; $$;

REVOKE ALL ON FUNCTION grado.puede_consultar_idea(bigint,bigint),grado.proponer_idea(text,jsonb),
 grado.decidir_idea(text,bigint,text,text),grado.crear_proyecto(text,bigint,jsonb),
 grado.presentar_pago(text,bigint,text,text),grado.decidir_pago(text,bigint,bigint,text,text),
 grado.asignar_docentes(text,bigint,bigint,bigint) FROM PUBLIC;
COMMIT;
