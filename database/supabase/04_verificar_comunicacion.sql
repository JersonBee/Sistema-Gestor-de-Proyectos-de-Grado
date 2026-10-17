-- Comprobación de solo lectura; no crea usuarios, proyectos ni mensajes.
DO $$
DECLARE firma text;
BEGIN
 FOREACH firma IN ARRAY ARRAY[
  'grado.administrar_cuenta(text,bigint,text,text,jsonb)',
  'grado.crear_acta(text,bigint,text,text,text,text)',
  'grado.aprobar_acta(text,bigint)',
  'grado.puede_consultar_acta(bigint,bigint)',
  'grado.enviar_mensaje(text,bigint,bigint,text)',
  'grado.leer_mensajes(text,bigint)'
 ] LOOP
  IF to_regprocedure(firma) IS NULL THEN RAISE EXCEPTION 'Falta la función %',firma; END IF;
 END LOOP;
 IF to_regclass('grado.mensaje_bandeja') IS NULL OR to_regclass('grado.acta_proyecto_consulta') IS NULL THEN
  RAISE EXCEPTION 'Faltan índices del módulo de comunicación';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='grado-procesar-plazos' AND active) THEN
  RAISE EXCEPTION 'El trabajo de plazos no está activo';
 END IF;
END; $$;
