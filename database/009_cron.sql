-- Exclusivo de Supabase (pg_cron disponible y precargado).
-- La base de pruebas ejecuta directamente procesar_plazos con un reloj controlado.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('grado-procesar-plazos','* * * * *','SELECT grado.procesar_plazos();');
COMMIT;
