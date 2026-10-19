-- Corrección de registro: las listas de áreas y líneas requieren al menos un valor.
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
REVOKE ALL ON FUNCTION grado.registrar_cuenta(text,text,text,text,text,text,jsonb) FROM PUBLIC;
COMMIT;
