-- Rechaza mensajes y campos de acta sin contenido visible.
-- Conserva firmas, permisos y registros existentes.
BEGIN;

CREATE OR REPLACE FUNCTION grado.enviar_mensaje(p_token text,p_proyecto bigint,p_destinatario bigint,p_contenido text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; destino record; p record; nuevo bigint; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 SELECT id,rol_codigo INTO destino FROM usuario WHERE id=p_destinatario AND estado='activo';
 IF actor.id IS NULL OR destino.id IS NULL OR actor.id=destino.id OR
 NOT ((actor.rol_codigo='estudiante' AND destino.rol_codigo='director' AND EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=actor.id AND retiro_en IS NULL) AND EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND docente_id=destino.id AND funcion='director' AND fin_en IS NULL)) OR
 (actor.rol_codigo='director' AND destino.rol_codigo='estudiante' AND EXISTS(SELECT 1 FROM asignacion_proyecto WHERE proyecto_id=p_proyecto AND docente_id=actor.id AND funcion='director' AND fin_en IS NULL) AND EXISTS(SELECT 1 FROM participante_proyecto WHERE proyecto_id=p_proyecto AND estudiante_id=destino.id AND retiro_en IS NULL))) THEN
  RETURN QUERY SELECT false,'El canal permite mensajes entre estudiantes vigentes y su director asignado.'::text,NULL::bigint; RETURN;
 END IF;
 PERFORM procesar_plazos_proyecto(p_proyecto,CURRENT_TIMESTAMP);
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto;
 IF p.estado IS DISTINCT FROM 'activo' OR nullif(regexp_replace(p_contenido, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR length(p_contenido)>12000 THEN
  RETURN QUERY SELECT false,'Escribe un mensaje para un proyecto activo.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO mensaje(proyecto_id,remitente_id,destinatario_id,contenido) VALUES(p_proyecto,actor.id,p_destinatario,regexp_replace(p_contenido, '^[[:space:]]+|[[:space:]]+$', '', 'g')) RETURNING id INTO nuevo;
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,actor.id,'usuario','enviar_mensaje','mensaje',nuevo,jsonb_build_object('detalle','Se envió un mensaje por el canal privado.')) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,p_destinatario,'Tienes un mensaje nuevo','Abre Mensajes en el proyecto para leerlo.');
 RETURN QUERY SELECT true,'Mensaje enviado.'::text,p_proyecto;
END; $$;

CREATE OR REPLACE FUNCTION grado.crear_acta(p_token text,p_proyecto bigint,p_numero text,p_fecha text,p_descripcion text,p_detalles text)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; p record; nueva bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN RETURN QUERY SELECT false,'Solo el Comité registra actas.'::text,NULL::bigint; RETURN; END IF;
 SELECT * INTO p FROM proyecto WHERE id=p_proyecto FOR UPDATE;
 IF p.id IS NULL OR p.estado='desactivado' THEN RETURN QUERY SELECT false,'El proyecto no existe o está en pausa.'::text,NULL::bigint; RETURN; END IF;
 IF nullif(regexp_replace(p_numero, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR nullif(regexp_replace(p_descripcion, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR nullif(regexp_replace(p_detalles, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL OR p_fecha IS NULL OR p_fecha!~ '^\d{4}-\d{2}-\d{2}$' THEN
  RETURN QUERY SELECT false,'Completa número, fecha, descripción y detalles del acta.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO acta(numero,fecha,descripcion,detalles,creada_por) VALUES(regexp_replace(p_numero, '^[[:space:]]+|[[:space:]]+$', '', 'g'),p_fecha::date,regexp_replace(p_descripcion, '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_detalles, '^[[:space:]]+|[[:space:]]+$', '', 'g'),actor.id) RETURNING id INTO nueva;
 INSERT INTO acta_proyecto(acta_id,proyecto_id) VALUES(nueva,p_proyecto);
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id) VALUES(p_proyecto,actor.id,'usuario','registrar_acta','acta',nueva);
 RETURN QUERY SELECT true,'Acta registrada. Falta la aprobación del Comité.'::text,nueva;
EXCEPTION WHEN unique_violation THEN RETURN QUERY SELECT false,'Ya existe un acta con ese número.'::text,NULL::bigint;
 WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN QUERY SELECT false,'Escribe una fecha válida.'::text,NULL::bigint;
END; $$;

COMMIT;
