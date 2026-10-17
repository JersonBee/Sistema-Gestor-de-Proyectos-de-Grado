BEGIN;
CREATE INDEX IF NOT EXISTS mensaje_bandeja ON grado.mensaje(destinatario_id,proyecto_id,enviado_en DESC);
CREATE INDEX IF NOT EXISTS acta_proyecto_consulta ON grado.acta_proyecto(proyecto_id,acta_id);

CREATE OR REPLACE FUNCTION grado.administrar_cuenta(p_token text,p_usuario bigint,p_rol text,p_estado text,p_perfil jsonb DEFAULT '{}')
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,extensions,pg_temp AS $$
DECLARE actor record; cuenta record; valor text; catalogo bigint; v_codigo text; campo text;
BEGIN
 -- Serializa cambios del Comité y revalida al actor después de tomar el bloqueo.
 PERFORM pg_advisory_xact_lock(740019);
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN RETURN QUERY SELECT false,'Solo el Comité administra cuentas.'::text,NULL::bigint; RETURN; END IF;
 SELECT * INTO cuenta FROM usuario WHERE id=p_usuario FOR UPDATE;
 IF cuenta.id IS NULL OR p_rol IS NULL OR p_rol NOT IN('estudiante','director','evaluador','comite','secretaria') OR p_estado IS NULL OR p_estado NOT IN('activo','inactivo','pendiente') THEN
  RETURN QUERY SELECT false,'Revisa la cuenta, el rol y el estado.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_usuario=actor.id AND (p_rol<>'comite' OR p_estado<>'activo') THEN
  RETURN QUERY SELECT false,'Conserva tu propia cuenta activa como Comité. Otra cuenta del Comité puede administrar este cambio.'::text,NULL::bigint; RETURN;
 END IF;
 IF cuenta.rol_codigo='comite' AND cuenta.estado='activo' AND (p_rol<>'comite' OR p_estado<>'activo') AND (SELECT count(*) FROM usuario WHERE rol_codigo='comite' AND estado='activo')<=1 THEN
  RETURN QUERY SELECT false,'Debe permanecer al menos una cuenta activa del Comité.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_rol<>cuenta.rol_codigo AND (EXISTS(SELECT 1 FROM participante_proyecto WHERE estudiante_id=p_usuario AND retiro_en IS NULL)
  OR EXISTS(SELECT 1 FROM asignacion_proyecto WHERE docente_id=p_usuario AND fin_en IS NULL)) THEN
  RETURN QUERY SELECT false,'La cuenta tiene una participación o asignación vigente. Resuelve su retiro o cambio de docente antes de cambiar el rol.'::text,NULL::bigint; RETURN;
 END IF;
 IF p_rol IN('director','evaluador') AND NOT EXISTS(SELECT 1 FROM perfil_docente WHERE usuario_id=p_usuario) THEN
  FOREACH campo IN ARRAY ARRAY['areas','lineas','modalidades','cursos','titulos','temas'] LOOP
   IF nullif(btrim(p_perfil->>campo),'') IS NULL THEN RETURN QUERY SELECT false,'Para asignar un rol docente, completa primero su perfil docente.'::text,NULL::bigint; RETURN; END IF;
  END LOOP;
  INSERT INTO perfil_docente(usuario_id,cursos,titulos_academicos,temas_preferencia) VALUES(p_usuario,btrim(p_perfil->>'cursos'),btrim(p_perfil->>'titulos'),btrim(p_perfil->>'temas'));
  FOR valor IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'areas',',') x WHERE btrim(x)<>'' LOOP
   INSERT INTO area_experiencia(nombre) VALUES(valor) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO catalogo;
   INSERT INTO docente_area VALUES(p_usuario,catalogo);
  END LOOP;
  FOR valor IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'lineas',',') x WHERE btrim(x)<>'' LOOP
   INSERT INTO linea_investigacion(nombre) VALUES(valor) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO catalogo;
   INSERT INTO docente_linea VALUES(p_usuario,catalogo);
  END LOOP;
  FOR v_codigo IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'modalidades',',') x LOOP
   SELECT id INTO catalogo FROM modalidad WHERE modalidad.codigo=v_codigo;
   IF catalogo IS NULL THEN RAISE EXCEPTION 'Modalidad inválida'; END IF;
   INSERT INTO docente_modalidad VALUES(p_usuario,catalogo);
  END LOOP;
 END IF;
 IF p_rol IN('director','evaluador') AND (NOT EXISTS(SELECT 1 FROM docente_area WHERE docente_id=p_usuario) OR NOT EXISTS(SELECT 1 FROM docente_linea WHERE docente_id=p_usuario) OR NOT EXISTS(SELECT 1 FROM docente_modalidad WHERE docente_id=p_usuario)) THEN
  RAISE EXCEPTION 'Perfil docente incompleto';
 END IF;
 UPDATE usuario SET rol_codigo=p_rol,estado=p_estado WHERE id=p_usuario;
 -- Un cambio de rol o estado revoca las sesiones anteriores, incluso al reactivar.
 IF p_rol<>cuenta.rol_codigo OR p_estado<>cuenta.estado THEN UPDATE sesion_acceso SET revocada=true WHERE usuario_id=p_usuario; END IF;
 INSERT INTO evento_auditoria(actor_id,origen,accion,entidad,entidad_id,datos_anteriores,datos_nuevos)
 VALUES(actor.id,'usuario','administrar_cuenta','usuario',p_usuario,jsonb_build_object('rol',cuenta.rol_codigo,'estado',cuenta.estado),jsonb_build_object('rol',p_rol,'estado',p_estado));
 RETURN QUERY SELECT true,'Cuenta actualizada. Los cambios de acceso se aplican inmediatamente.'::text,p_usuario;
EXCEPTION WHEN raise_exception OR foreign_key_violation OR invalid_text_representation THEN RETURN QUERY SELECT false,'Revisa los datos del perfil docente.'::text,NULL::bigint;
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
 IF nullif(btrim(p_numero),'') IS NULL OR nullif(btrim(p_descripcion),'') IS NULL OR nullif(btrim(p_detalles),'') IS NULL OR p_fecha IS NULL OR p_fecha!~ '^\d{4}-\d{2}-\d{2}$' THEN
  RETURN QUERY SELECT false,'Completa número, fecha, descripción y detalles del acta.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO acta(numero,fecha,descripcion,detalles,creada_por) VALUES(btrim(p_numero),p_fecha::date,btrim(p_descripcion),btrim(p_detalles),actor.id) RETURNING id INTO nueva;
 INSERT INTO acta_proyecto(acta_id,proyecto_id) VALUES(nueva,p_proyecto);
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id) VALUES(p_proyecto,actor.id,'usuario','registrar_acta','acta',nueva);
 RETURN QUERY SELECT true,'Acta registrada. Falta la aprobación del Comité.'::text,nueva;
EXCEPTION WHEN unique_violation THEN RETURN QUERY SELECT false,'Ya existe un acta con ese número.'::text,NULL::bigint;
 WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN QUERY SELECT false,'Escribe una fecha válida.'::text,NULL::bigint;
END; $$;

CREATE OR REPLACE FUNCTION grado.aprobar_acta(p_token text,p_acta bigint)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record; a record; p record; evento bigint;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR actor.rol_codigo<>'comite' THEN RETURN QUERY SELECT false,'Solo el Comité aprueba actas.'::text,NULL::bigint; RETURN; END IF;
 -- Orden de bloqueos igual al resto de trámites: proyecto, después acta.
 FOR p IN SELECT pr.id,pr.estado FROM proyecto pr JOIN acta_proyecto ap ON ap.proyecto_id=pr.id WHERE ap.acta_id=p_acta ORDER BY pr.id FOR UPDATE OF pr LOOP
  IF p.estado='desactivado' THEN RETURN QUERY SELECT false,'Un proyecto vinculado está en pausa.'::text,NULL::bigint; RETURN; END IF;
 END LOOP;
 SELECT * INTO a FROM acta WHERE id=p_acta FOR UPDATE;
 IF a.id IS NULL OR a.aprobada_en IS NOT NULL OR NOT EXISTS(SELECT 1 FROM acta_proyecto WHERE acta_id=p_acta) THEN RETURN QUERY SELECT false,'El acta no existe o ya fue aprobada.'::text,NULL::bigint; RETURN; END IF;
 UPDATE acta SET aprobada_por=actor.id,aprobada_en=CURRENT_TIMESTAMP WHERE id=p_acta;
 FOR p IN SELECT proyecto_id FROM acta_proyecto WHERE acta_id=p_acta LOOP
  INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
  VALUES(p.proyecto_id,actor.id,'usuario','aprobar_acta','acta',p_acta,jsonb_build_object('detalle','Acta '||a.numero||' aprobada.')) RETURNING id INTO evento;
  INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo)
  SELECT evento,id,'Acta aprobada','Ya puedes consultar el acta '||a.numero||'.' FROM (
   SELECT estudiante_id AS id FROM participante_proyecto WHERE proyecto_id=p.proyecto_id
   UNION SELECT docente_id FROM asignacion_proyecto WHERE proyecto_id=p.proyecto_id
   UNION SELECT id FROM usuario WHERE rol_codigo='comite' AND estado='activo') destinatarios;
 END LOOP;
 RETURN QUERY SELECT true,'Acta aprobada y disponible para consulta.'::text,p_acta;
END; $$;

CREATE OR REPLACE FUNCTION grado.puede_consultar_acta(p_usuario bigint,p_acta bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=grado,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM acta a JOIN acta_proyecto ap ON ap.acta_id=a.id JOIN usuario u ON u.id=p_usuario WHERE a.id=p_acta AND u.estado='activo'
  AND (u.rol_codigo='comite' OR (a.aprobada_en IS NOT NULL AND puede_consultar_proyecto(u.id,ap.proyecto_id))));
$$;

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
 IF p.estado IS DISTINCT FROM 'activo' OR nullif(btrim(p_contenido),'') IS NULL OR length(p_contenido)>12000 THEN
  RETURN QUERY SELECT false,'Escribe un mensaje para un proyecto activo.'::text,NULL::bigint; RETURN;
 END IF;
 INSERT INTO mensaje(proyecto_id,remitente_id,destinatario_id,contenido) VALUES(p_proyecto,actor.id,p_destinatario,btrim(p_contenido)) RETURNING id INTO nuevo;
 INSERT INTO evento_auditoria(proyecto_id,actor_id,origen,accion,entidad,entidad_id,datos_nuevos)
 VALUES(p_proyecto,actor.id,'usuario','enviar_mensaje','mensaje',nuevo,jsonb_build_object('detalle','Se envió un mensaje por el canal privado.')) RETURNING id INTO evento;
 INSERT INTO notificacion(evento_id,destinatario_id,asunto,cuerpo) VALUES(evento,p_destinatario,'Tienes un mensaje nuevo','Abre Mensajes en el proyecto para leerlo.');
 RETURN QUERY SELECT true,'Mensaje enviado.'::text,p_proyecto;
END; $$;
CREATE OR REPLACE FUNCTION grado.leer_mensajes(p_token text,p_proyecto bigint)
RETURNS TABLE(ok boolean,mensaje text,recurso_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=grado,pg_temp AS $$
DECLARE actor record;
BEGIN
 SELECT * INTO actor FROM validar_sesion(p_token);
 IF actor.id IS NULL OR NOT puede_consultar_proyecto(actor.id,p_proyecto) THEN
  RETURN QUERY SELECT false,'No tienes acceso al proyecto.'::text,NULL::bigint; RETURN;
 END IF;
 UPDATE grado.mensaje SET leido_en=CURRENT_TIMESTAMP WHERE proyecto_id=p_proyecto AND destinatario_id=actor.id AND leido_en IS NULL;
 RETURN QUERY SELECT true,'Mensajes recibidos marcados como leídos.'::text,p_proyecto;
END; $$;
REVOKE ALL ON FUNCTION grado.leer_mensajes(text,bigint),grado.administrar_cuenta(text,bigint,text,text,jsonb),grado.crear_acta(text,bigint,text,text,text,text),
 grado.aprobar_acta(text,bigint),grado.puede_consultar_acta(bigint,bigint),grado.enviar_mensaje(text,bigint,bigint,text) FROM PUBLIC;
COMMIT;
