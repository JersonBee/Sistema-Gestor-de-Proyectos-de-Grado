-- Exclusivamente en grado-pruebas después de las pruebas de acceso.
-- Comprueba la reposición de espera, vigencia y corrección; revierte sus datos.
BEGIN;
DO $$
DECLARE actor bigint; docente bigint; estudiante bigint; token text; idea_nueva bigint; proyecto_nuevo bigint;
 fase_id bigint; entrega bigint; ciclo bigint; revision bigint; correccion bigint; resultado record;
 inicio timestamptz:=CURRENT_TIMESTAMP; habilitado timestamptz; vence timestamptz; corr_limite timestamptz;
BEGIN
 SELECT id INTO actor FROM grado.usuario WHERE rol_codigo='comite' AND estado='activo' LIMIT 1;
 SELECT id INTO docente FROM grado.usuario WHERE rol_codigo='director' AND estado='activo' LIMIT 1;
 SELECT id INTO estudiante FROM grado.usuario WHERE rol_codigo='estudiante' AND estado='activo' LIMIT 1;
 IF actor IS NULL OR docente IS NULL OR estudiante IS NULL THEN RAISE EXCEPTION 'Faltan fixtures de grado-pruebas.'; END IF;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 INSERT INTO grado.sesion_acceso(token_hash,usuario_id) VALUES(encode(extensions.digest(token,'sha256'),'hex'),actor);
 INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado)
 SELECT estudiante,modalidad_id,area_id,linea_id,'Pausa de prueba','Prueba','Prueba','Prueba','aprobada' FROM grado.idea LIMIT 1 RETURNING id INTO idea_nueva;
 habilitado:=grado.habilitacion_informe(inicio); vence:=grado.limite_dias_calendario(inicio,180); corr_limite:=grado.limite_dias_calendario(inicio,3);
 INSERT INTO grado.proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por,inicio_vigencia_en,informe_habilitado_en,vence_en)
 SELECT idea_nueva,modalidad_id,'Pausa de prueba','Prueba','Prueba',estudiante,inicio,habilitado,vence FROM grado.idea WHERE id=idea_nueva RETURNING id INTO proyecto_nuevo;
 INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(proyecto_nuevo,'informe_1',inicio) RETURNING id INTO fase_id;
 INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) VALUES(proyecto_nuevo,fase_id,1,estudiante) RETURNING id INTO entrega;
 INSERT INTO grado.ciclo_revision(entrega_id,numero,finalizado_en) VALUES(entrega,1,inicio) RETURNING id INTO ciclo;
 INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id,decision,reporte_respuesta,decidida_en)
 VALUES(ciclo,'director',docente,'rechazado','Prueba',inicio) RETURNING id INTO revision;
 INSERT INTO grado.plazo_correccion(revision_id,inicio_en,limite_en) VALUES(revision,inicio,corr_limite) RETURNING id INTO correccion;
 SELECT * INTO resultado FROM grado.cambiar_pausa(token,proyecto_nuevo,true,'Pausa de prueba');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'No pausó el proyecto.'; END IF;
 UPDATE grado.pausa_proyecto SET inicio_en=CURRENT_TIMESTAMP-interval '26 hours' WHERE proyecto_id=proyecto_nuevo AND fin_en IS NULL;
 PERFORM grado.procesar_plazos_proyecto(proyecto_nuevo,vence+interval '1 day');
 IF NOT EXISTS(SELECT 1 FROM grado.proyecto WHERE id=proyecto_nuevo AND estado='desactivado') THEN RAISE EXCEPTION 'Canceló durante la pausa.'; END IF;
 SELECT * INTO resultado FROM grado.cambiar_pausa(token,proyecto_nuevo,false,NULL);
 IF NOT resultado.ok OR NOT EXISTS(SELECT 1 FROM grado.proyecto WHERE id=proyecto_nuevo AND inicio_vigencia_en=inicio
  AND informe_habilitado_en=habilitado+interval '2 days' AND vence_en=vence+interval '2 days'
  AND to_char(vence_en AT TIME ZONE 'America/Bogota','HH24:MI')='23:59') THEN RAISE EXCEPTION 'No repuso correctamente espera y vigencia.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM grado.plazo_correccion WHERE id=correccion AND limite_en=corr_limite+interval '2 days') THEN RAISE EXCEPTION 'No repuso el plazo de corrección.'; END IF;
END; $$;
ROLLBACK;
