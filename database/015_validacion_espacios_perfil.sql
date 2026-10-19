-- Validacion de nombres, perfiles docentes y elementos de listas con espacios, tabs o saltos.
-- Reemplaza funciones; no modifica cuentas existentes ni cambia la autoactivacion.
BEGIN;

CREATE OR REPLACE FUNCTION grado.registrar_cuenta(
    p_nombre text, p_correo text, p_contrasena text, p_documento text,
    p_telefono text, p_rol text, p_perfil jsonb DEFAULT '{}'::jsonb)
RETURNS TABLE(ok boolean, mensaje text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, extensions, pg_temp AS $$
DECLARE cuenta_id bigint; valor text; catalogo_id bigint; codigo_modalidad text;
BEGIN
    IF p_rol IS NULL OR p_rol NOT IN ('estudiante', 'director', 'evaluador') THEN
        RETURN QUERY SELECT false, 'El tipo de cuenta no está permitido.'::text; RETURN;
    END IF;
    IF length(regexp_replace(coalesce(p_nombre,''), '^[[:space:]]+|[[:space:]]+$', '', 'g')) NOT BETWEEN 2 AND 120
        OR length(coalesce(p_correo,'')) > 254
        OR coalesce(p_correo,'') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
        OR length(coalesce(p_contrasena,'')) < 8 OR octet_length(coalesce(p_contrasena,'')) > 72
        OR length(coalesce(p_documento,'')) > 40 OR length(coalesce(p_telefono,'')) > 40
        OR length(coalesce(p_perfil::text,'')) > 20000 THEN
        RETURN QUERY SELECT false, 'Revisa los datos. La contraseña debe tener al menos 8 caracteres y como máximo 72 bytes.'::text; RETURN;
    END IF;
    IF p_rol IN ('director','evaluador') AND (
        regexp_replace(coalesce(p_perfil->>'cursos',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = '' OR regexp_replace(coalesce(p_perfil->>'titulos',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = ''
        OR regexp_replace(coalesce(p_perfil->>'temas',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = '' OR regexp_replace(coalesce(p_perfil->>'areas',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = ''
        OR regexp_replace(coalesce(p_perfil->>'lineas',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = '' OR regexp_replace(coalesce(p_perfil->>'modalidades',''), '^[[:space:]]+|[[:space:]]+$', '', 'g') = '') THEN
        RETURN QUERY SELECT false, 'Completa los campos de tu perfil docente.'::text; RETURN;
    END IF;
    IF p_rol IN ('director','evaluador') AND (
        NOT EXISTS (SELECT 1 FROM regexp_split_to_table(coalesce(p_perfil->>'areas',''), ',') x
                    WHERE regexp_replace(x, '[[:space:]]', '', 'g') <> '')
        OR NOT EXISTS (SELECT 1 FROM regexp_split_to_table(coalesce(p_perfil->>'lineas',''), ',') x
                       WHERE regexp_replace(x, '[[:space:]]', '', 'g') <> '')) THEN
        RETURN QUERY SELECT false, 'Registra al menos un área de experiencia y una línea de investigación.'::text; RETURN;
    END IF;
    INSERT INTO grado.usuario(nombre, correo, contrasena_hash, numero_documento, telefono, rol_codigo)
    VALUES (regexp_replace(p_nombre, '^[[:space:]]+|[[:space:]]+$', '', 'g'), lower(regexp_replace(p_correo, '^[[:space:]]+|[[:space:]]+$', '', 'g')), grado.crear_hash_contrasena(p_contrasena),
        nullif(regexp_replace(p_documento, '^[[:space:]]+|[[:space:]]+$', '', 'g'),''), nullif(regexp_replace(p_telefono, '^[[:space:]]+|[[:space:]]+$', '', 'g'),''), p_rol) RETURNING id INTO cuenta_id;
    IF p_rol <> 'estudiante' THEN
        INSERT INTO grado.perfil_docente(usuario_id, cursos, titulos_academicos, temas_preferencia)
            VALUES (cuenta_id, regexp_replace(p_perfil->>'cursos', '^[[:space:]]+|[[:space:]]+$', '', 'g'), regexp_replace(p_perfil->>'titulos', '^[[:space:]]+|[[:space:]]+$', '', 'g'), regexp_replace(p_perfil->>'temas', '^[[:space:]]+|[[:space:]]+$', '', 'g'));
        FOR valor IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'areas', ',') x WHERE regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') <> '' LOOP
            INSERT INTO grado.area_experiencia(nombre) VALUES (valor) ON CONFLICT (nombre) DO UPDATE SET nombre = excluded.nombre RETURNING id INTO catalogo_id;
            INSERT INTO grado.docente_area VALUES (cuenta_id, catalogo_id);
        END LOOP;
        FOR valor IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'lineas', ',') x WHERE regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') <> '' LOOP
            INSERT INTO grado.linea_investigacion(nombre) VALUES (valor) ON CONFLICT (nombre) DO UPDATE SET nombre = excluded.nombre RETURNING id INTO catalogo_id;
            INSERT INTO grado.docente_linea VALUES (cuenta_id, catalogo_id);
        END LOOP;
        FOR codigo_modalidad IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'modalidades', ',') x LOOP
            SELECT m.id INTO catalogo_id FROM grado.modalidad m WHERE m.codigo = codigo_modalidad;
            IF catalogo_id IS NULL THEN RAISE EXCEPTION 'Modalidad inválida'; END IF;
            INSERT INTO grado.docente_modalidad VALUES (cuenta_id, catalogo_id);
        END LOOP;
    END IF;
    INSERT INTO grado.evento_auditoria(actor_id, origen, accion, entidad, entidad_id)
        VALUES (cuenta_id, 'usuario', 'registro_cuenta', 'usuario', cuenta_id);
    RETURN QUERY SELECT true, 'Tu cuenta está activa. Ya puedes iniciar sesión.'::text;
EXCEPTION
    WHEN unique_violation THEN RETURN QUERY SELECT false, 'No se pudo registrar la cuenta con esos datos. Si ya tienes cuenta, inicia sesión.'::text;
    WHEN raise_exception OR invalid_text_representation OR foreign_key_violation THEN
        RETURN QUERY SELECT false, 'Revisa los datos y las modalidades de tu perfil.'::text;
END;
$$;

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
   IF nullif(regexp_replace(p_perfil->>campo, '^[[:space:]]+|[[:space:]]+$', '', 'g'),'') IS NULL THEN RETURN QUERY SELECT false,'Para asignar un rol docente, completa primero su perfil docente.'::text,NULL::bigint; RETURN; END IF;
  END LOOP;
  INSERT INTO perfil_docente(usuario_id,cursos,titulos_academicos,temas_preferencia) VALUES(p_usuario,regexp_replace(p_perfil->>'cursos', '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_perfil->>'titulos', '^[[:space:]]+|[[:space:]]+$', '', 'g'),regexp_replace(p_perfil->>'temas', '^[[:space:]]+|[[:space:]]+$', '', 'g'));
  FOR valor IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'areas',',') x WHERE regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g')<>'' LOOP
   INSERT INTO area_experiencia(nombre) VALUES(valor) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO catalogo;
   INSERT INTO docente_area VALUES(p_usuario,catalogo);
  END LOOP;
  FOR valor IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'lineas',',') x WHERE regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g')<>'' LOOP
   INSERT INTO linea_investigacion(nombre) VALUES(valor) ON CONFLICT(nombre) DO UPDATE SET nombre=excluded.nombre RETURNING id INTO catalogo;
   INSERT INTO docente_linea VALUES(p_usuario,catalogo);
  END LOOP;
  FOR v_codigo IN SELECT DISTINCT regexp_replace(x, '^[[:space:]]+|[[:space:]]+$', '', 'g') FROM regexp_split_to_table(p_perfil->>'modalidades',',') x LOOP
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

COMMIT;
