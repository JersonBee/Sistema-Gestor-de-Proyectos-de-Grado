-- Solo grado-pruebas. Sin adicionales obligatorios; todo se revierte.
BEGIN;
DO $$
DECLARE actor bigint; estudiante bigint; token text; idea_nueva bigint; pid bigint; resultado record;
BEGIN
 SELECT id INTO actor FROM grado.usuario WHERE rol_codigo='comite' AND estado='activo' LIMIT 1;
 SELECT id INTO estudiante FROM grado.usuario WHERE rol_codigo='estudiante' AND estado='activo' LIMIT 1;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 INSERT INTO grado.sesion_acceso(token_hash,usuario_id) VALUES(encode(extensions.digest(token,'sha256'),'hex'),actor);
 INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado)
 SELECT estudiante,modalidad_id,area_id,linea_id,'Final sin adicionales','Prueba','Prueba','Prueba','aprobada' FROM grado.idea LIMIT 1 RETURNING id INTO idea_nueva;
 INSERT INTO grado.proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por,inicio_vigencia_en,informe_habilitado_en,vence_en,informe_aprobado_comite_en)
 SELECT idea_nueva,modalidad_id,'Final sin adicionales','Prueba','Prueba',estudiante,CURRENT_TIMESTAMP-interval '100 days',CURRENT_TIMESTAMP-interval '10 days',CURRENT_TIMESTAMP+interval '80 days',CURRENT_TIMESTAMP FROM grado.idea WHERE id=idea_nueva RETURNING id INTO pid;
 INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(pid,'final',CURRENT_TIMESTAMP);
 SELECT * INTO resultado FROM grado.finalizar_proyecto(token,pid,NULL);
 IF NOT resultado.ok OR NOT EXISTS(SELECT 1 FROM grado.proyecto WHERE id=pid AND estado='finalizado') THEN RAISE EXCEPTION 'Exigió adicionales opcionales para cerrar.'; END IF;
 IF EXISTS(SELECT 1 FROM grado.entrega_final WHERE proyecto_id=pid) THEN RAISE EXCEPTION 'Creó datos finales ficticios.'; END IF;
END; $$;
ROLLBACK;
