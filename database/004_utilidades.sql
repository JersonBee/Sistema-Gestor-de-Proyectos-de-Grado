-- Después de 001 y 002. No crea cuentas ni activa tareas Cron.
BEGIN;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
-- No reubicar una extensión existente ni afectar componentes de Supabase.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
        WHERE e.extname = 'pgcrypto' AND n.nspname = 'extensions') THEN
        RAISE EXCEPTION 'pgcrypto está en otro esquema; adaptar las referencias antes de ejecutar este archivo.';
    END IF;
END;
$$;

CREATE FUNCTION grado.crear_hash_contrasena(contrasena text) RETURNS text
LANGUAGE plpgsql STRICT SECURITY INVOKER
SET search_path = grado, extensions, pg_temp AS $$
BEGIN
    -- bcrypt limita a 72 bytes; no permitir truncamiento silencioso.
    IF octet_length(contrasena) = 0 OR octet_length(contrasena) > 72 THEN
        RAISE EXCEPTION 'La contraseña debe tener entre 1 y 72 bytes UTF-8.';
    END IF;
    RETURN extensions.crypt(contrasena, extensions.gen_salt('bf', 12));
END;
$$;
CREATE FUNCTION grado.verificar_hash_contrasena(contrasena text, hash_guardado text)
RETURNS boolean LANGUAGE plpgsql STRICT SECURITY INVOKER
SET search_path = grado, extensions, pg_temp AS $$
BEGIN
    IF octet_length(contrasena) = 0 OR octet_length(contrasena) > 72
        OR hash_guardado !~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$' THEN
        RETURN false;
    END IF;
    RETURN extensions.crypt(contrasena, hash_guardado) = hash_guardado;
END;
$$;
-- Conceder EXECUTE exclusivamente al rol de conexión de la aplicación al crearlo.
REVOKE ALL ON FUNCTION grado.crear_hash_contrasena(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION grado.verificar_hash_contrasena(text, text) FROM PUBLIC;

CREATE FUNCTION grado.limite_dias_calendario(inicio timestamptz, dias integer)
RETURNS timestamptz LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER
SET search_path = grado, pg_temp AS $$
BEGIN
    IF dias < 0 THEN RAISE EXCEPTION 'El plazo no puede ser negativo.'; END IF;
    -- El día del evento es día cero; vence a las 23:59 del último día en Bogotá.
    RETURN (((inicio AT TIME ZONE 'America/Bogota')::date + dias)
        + time '23:59:00') AT TIME ZONE 'America/Bogota';
END;
$$;
CREATE FUNCTION grado.habilitacion_informe(inicio timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER
SET search_path = grado, pg_temp AS $$
    SELECT (((inicio AT TIME ZONE 'America/Bogota')::date + 90)
        + time '00:00:00') AT TIME ZONE 'America/Bogota';
$$;
COMMIT;
