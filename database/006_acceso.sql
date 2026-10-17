-- Migración aditiva: T-01/T-02 y registro docente con perfil (RF-01/09).
-- No modifica cuentas existentes ni crea credenciales de administración.
BEGIN;
CREATE TABLE IF NOT EXISTS grado.sesion_acceso (
    token_hash text PRIMARY KEY,
    usuario_id bigint NOT NULL REFERENCES grado.usuario(id),
    creada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vence_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP + interval '8 hours',
    revocada boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS sesion_acceso_usuario ON grado.sesion_acceso(usuario_id, vence_en);
CREATE TABLE IF NOT EXISTS grado.intento_acceso (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    correo_hash text NOT NULL,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS intento_acceso_ventana ON grado.intento_acceso(correo_hash, creado_en);

CREATE OR REPLACE FUNCTION grado.validar_sesion(p_token text)
RETURNS TABLE(id bigint, nombre text, correo text, rol_codigo text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = grado, extensions, pg_temp AS $$
    SELECT u.id, u.nombre, u.correo, u.rol_codigo
    FROM grado.sesion_acceso s JOIN grado.usuario u ON u.id = s.usuario_id
    WHERE s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
        AND length(p_token) = 64 AND NOT s.revocada
        AND s.vence_en > CURRENT_TIMESTAMP AND u.estado = 'activo';
$$;
CREATE OR REPLACE FUNCTION grado.iniciar_sesion(p_correo text, p_contrasena text)
RETURNS TABLE(token text, nombre text, rol_codigo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = grado, extensions, pg_temp AS $$
DECLARE cuenta grado.usuario%ROWTYPE; clave text; huella text; calculado text;
BEGIN
    IF p_correo IS NULL OR p_contrasena IS NULL OR length(p_correo) > 254
        OR octet_length(p_contrasena) > 72 OR octet_length(p_contrasena) = 0 THEN RETURN; END IF;
    huella := encode(extensions.digest(lower(btrim(p_correo)), 'sha256'), 'hex');
    PERFORM pg_advisory_xact_lock(hashtextextended(huella, 0));
    IF (SELECT count(*) FROM grado.intento_acceso i
        WHERE i.correo_hash = huella AND i.creado_en > CURRENT_TIMESTAMP - interval '15 minutes') >= 10 THEN RETURN; END IF;
    SELECT * INTO cuenta FROM grado.usuario u WHERE lower(u.correo) = lower(btrim(p_correo));
    -- Una operación bcrypt también cuando la cuenta no existe; error siempre genérico.
    calculado := extensions.crypt(p_contrasena, CASE
        WHEN cuenta.contrasena_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'
        THEN cuenta.contrasena_hash ELSE extensions.gen_salt('bf', 12) END);
    IF cuenta.id IS NULL OR cuenta.estado <> 'activo' OR calculado <> cuenta.contrasena_hash THEN
        INSERT INTO grado.intento_acceso(correo_hash) VALUES (huella);
        RETURN;
    END IF;
    DELETE FROM grado.intento_acceso i WHERE i.correo_hash = huella;
    clave := encode(extensions.gen_random_bytes(32), 'hex');
    INSERT INTO grado.sesion_acceso(token_hash, usuario_id)
        VALUES (encode(extensions.digest(clave, 'sha256'), 'hex'), cuenta.id);
    RETURN QUERY SELECT clave, cuenta.nombre, cuenta.rol_codigo;
END;
$$;
CREATE OR REPLACE FUNCTION grado.cerrar_sesion(p_token text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = grado, extensions, pg_temp AS $$
    UPDATE grado.sesion_acceso SET revocada = true
        WHERE token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;
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
    IF length(btrim(coalesce(p_nombre,''))) NOT BETWEEN 2 AND 120
        OR length(coalesce(p_correo,'')) > 254
        OR coalesce(p_correo,'') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
        OR length(coalesce(p_contrasena,'')) < 8 OR octet_length(coalesce(p_contrasena,'')) > 72
        OR length(coalesce(p_documento,'')) > 40 OR length(coalesce(p_telefono,'')) > 40
        OR length(coalesce(p_perfil::text,'')) > 20000 THEN
        RETURN QUERY SELECT false, 'Revisa los datos. La contraseña debe tener al menos 8 caracteres y como máximo 72 bytes.'::text; RETURN;
    END IF;
    IF p_rol IN ('director','evaluador') AND (
        btrim(coalesce(p_perfil->>'cursos','')) = '' OR btrim(coalesce(p_perfil->>'titulos','')) = ''
        OR btrim(coalesce(p_perfil->>'temas','')) = '' OR btrim(coalesce(p_perfil->>'areas','')) = ''
        OR btrim(coalesce(p_perfil->>'lineas','')) = '' OR btrim(coalesce(p_perfil->>'modalidades','')) = '') THEN
        RETURN QUERY SELECT false, 'Completa los campos de tu perfil docente.'::text; RETURN;
    END IF;
    INSERT INTO grado.usuario(nombre, correo, contrasena_hash, numero_documento, telefono, rol_codigo)
    VALUES (btrim(p_nombre), lower(btrim(p_correo)), grado.crear_hash_contrasena(p_contrasena),
        nullif(btrim(p_documento),''), nullif(btrim(p_telefono),''), p_rol) RETURNING id INTO cuenta_id;
    IF p_rol <> 'estudiante' THEN
        INSERT INTO grado.perfil_docente(usuario_id, cursos, titulos_academicos, temas_preferencia)
            VALUES (cuenta_id, btrim(p_perfil->>'cursos'), btrim(p_perfil->>'titulos'), btrim(p_perfil->>'temas'));
        FOR valor IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'areas', ',') x WHERE btrim(x) <> '' LOOP
            INSERT INTO grado.area_experiencia(nombre) VALUES (valor) ON CONFLICT (nombre) DO UPDATE SET nombre = excluded.nombre RETURNING id INTO catalogo_id;
            INSERT INTO grado.docente_area VALUES (cuenta_id, catalogo_id);
        END LOOP;
        FOR valor IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'lineas', ',') x WHERE btrim(x) <> '' LOOP
            INSERT INTO grado.linea_investigacion(nombre) VALUES (valor) ON CONFLICT (nombre) DO UPDATE SET nombre = excluded.nombre RETURNING id INTO catalogo_id;
            INSERT INTO grado.docente_linea VALUES (cuenta_id, catalogo_id);
        END LOOP;
        FOR codigo_modalidad IN SELECT DISTINCT btrim(x) FROM regexp_split_to_table(p_perfil->>'modalidades', ',') x LOOP
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

CREATE OR REPLACE FUNCTION grado.puede_consultar_proyecto(p_usuario bigint, p_proyecto bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = grado, pg_temp AS $$
    SELECT EXISTS (SELECT 1 FROM grado.usuario u WHERE u.id = p_usuario AND u.estado = 'activo' AND (
        u.rol_codigo IN ('comite','secretaria') OR
        (u.rol_codigo = 'estudiante' AND EXISTS (SELECT 1 FROM grado.participante_proyecto pp WHERE pp.proyecto_id = p_proyecto AND pp.estudiante_id = u.id)) OR
        (u.rol_codigo IN ('director','evaluador') AND EXISTS (SELECT 1 FROM grado.asignacion_proyecto ap WHERE ap.proyecto_id = p_proyecto AND ap.docente_id = u.id AND ap.fin_en IS NULL))));
$$;
-- Las funciones se consumirán desde el servidor; no se exponen como RPC público.
REVOKE ALL ON grado.sesion_acceso, grado.intento_acceso FROM PUBLIC;
REVOKE ALL ON FUNCTION grado.validar_sesion(text), grado.iniciar_sesion(text,text),
    grado.cerrar_sesion(text), grado.registrar_cuenta(text,text,text,text,text,text,jsonb),
    grado.puede_consultar_proyecto(bigint,bigint) FROM PUBLIC;
COMMIT;
