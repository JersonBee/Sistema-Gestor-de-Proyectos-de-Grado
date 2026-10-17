-- Solo lectura: confirma que la corrección está instalada, sin registrar cuentas.
DO $$
BEGIN
 IF position('Registra al menos un área de experiencia y una línea de investigación.' IN
  pg_get_functiondef('grado.registrar_cuenta(text,text,text,text,text,text,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Falta la validación de listas docentes';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='grado-procesar-plazos' AND active) THEN
  RAISE EXCEPTION 'El trabajo de plazos no está activo';
 END IF;
END; $$;
