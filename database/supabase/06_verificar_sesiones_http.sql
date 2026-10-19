-- Solo lectura: confirma la migración 013 sin consultar identificadores o tokens.
BEGIN READ ONLY;
DO $$
BEGIN
    IF to_regclass('grado.sesion_http') IS NULL THEN
        RAISE EXCEPTION 'Falta la migración 013';
    END IF;
    IF (SELECT count(*) FROM information_schema.columns
        WHERE table_schema='grado' AND table_name='sesion_http'
          AND column_name IN ('id','aplicacion','datos','valida','inactividad_maxima','ultimo_acceso')) <> 6 THEN
        RAISE EXCEPTION 'Almacén HTTP incompleto';
    END IF;
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='grado.sesion_http'::regclass) THEN
        RAISE EXCEPTION 'Falta RLS en almacén HTTP';
    END IF;
END $$;
ROLLBACK;
