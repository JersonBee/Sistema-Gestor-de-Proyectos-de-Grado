-- Solo lectura. Ejecutar después de 008/009 y de al menos un minuto.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN RAISE EXCEPTION 'Falta pg_cron.'; END IF;
 IF (SELECT count(*) FROM cron.job WHERE jobname='grado-procesar-plazos')<>1 OR NOT EXISTS(
  SELECT 1 FROM cron.job WHERE jobname='grado-procesar-plazos' AND active AND schedule='* * * * *' AND command='SELECT grado.procesar_plazos();') THEN
  RAISE EXCEPTION 'El trabajo de plazos no tiene la configuración esperada.';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job_run_details r JOIN cron.job j ON j.jobid=r.jobid
  WHERE j.jobname='grado-procesar-plazos' AND r.status='succeeded' AND r.end_time>CURRENT_TIMESTAMP-interval '5 minutes') THEN
  RAISE EXCEPTION 'Todavía no hay una ejecución reciente correcta.';
 END IF;
END; $$;
ROLLBACK;
