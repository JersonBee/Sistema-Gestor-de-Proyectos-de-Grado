-- Rechaza ideas y observaciones compuestas solo por espacios, tabs o saltos.
-- No modifica ideas existentes ni cambia permisos de funciones.
BEGIN;

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
  IF nullif(regexp_replace(p_datos->>campo, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL THEN
   RETURN QUERY SELECT false,'Completa todos los campos de la idea.'::text,NULL::bigint; RETURN;
  END IF;
 END LOOP;
 IF length(p_datos->>'titulo')>250 OR length(p_datos::text)>64000 THEN
  RETURN QUERY SELECT false,'El contenido es demasiado largo.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO area_experiencia(nombre) VALUES(regexp_replace(p_datos->>'area', '^[[:space:]]+|[[:space:]]+$', '', 'g')) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO area;
 INSERT INTO linea_investigacion(nombre) VALUES(regexp_replace(p_datos->>'linea', '^[[:space:]]+|[[:space:]]+$', '', 'g')) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO linea;
 INSERT INTO idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias)
 VALUES(actor.id,(p_datos->>'modalidad')::bigint,area,linea,regexp_replace(p_datos->>'titulo', '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_datos->>'descripcion', '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_datos->>'objetivos', '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_datos->>'tecnologias', '^[[:space:]]+|[[:space:]]+$', '', 'g')) RETURNING id INTO nueva;
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
 IF p_decision IS NULL OR p_decision NOT IN ('aprobada','rechazada') OR nullif(regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL THEN
  RETURN QUERY SELECT false,'Selecciona una decisión y escribe sus observaciones.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO decision_idea(idea_id,responsable_id,decision,observaciones) VALUES(p_idea,actor.id,p_decision,regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 UPDATE idea SET estado=p_decision WHERE id=p_idea;
 INSERT INTO evento_auditoria(actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(actor.id,'usuario','decidir_idea','idea',p_idea,jsonb_build_object('decision',p_decision,'reporte',regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'))) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,propuesta.autor_id,'Tu idea fue revisada',p_decision||': '||regexp_replace(p_reporte, '^[[:space:]]+|[[:space:]]+$', '', 'g'));
 RETURN QUERY SELECT true,'La decisión quedó registrada.'::text,p_idea;
END; $$;

COMMIT;
