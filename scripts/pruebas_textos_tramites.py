"""Reportes y solicitudes obligatorios; fixtures locales en transacción revertida."""
from pruebas_acceso import sql


def verificar_textos_tramites():
    assert sql('SELECT current_database();').strip() == 'grado_pruebas'
    sql(r"""
BEGIN;
DO $test$
DECLARE alumno bigint; comite bigint; director bigint; v_idea bigint; pid bigint;
    fase bigint; entrega bigint; ciclo bigint; revision bigint; tramite bigint;
    resultado record; vacio text;
    prefijo text := 'qa-tramites-' || txid_current();
    ta text := repeat(md5(random()::text),2);
    tc text := repeat(md5(random()::text),2);
    td text := repeat(md5(random()::text),2);
BEGIN
 IF current_database()<>'grado_pruebas' THEN RAISE EXCEPTION 'Solo pruebas locales'; END IF;
 INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado)
 VALUES('Alumno QA',prefijo||'@prueba.invalid','fixture','estudiante','activo') RETURNING id INTO alumno;
 INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado)
 VALUES('Comité QA',prefijo||'-comite@prueba.invalid','fixture','comite','activo') RETURNING id INTO comite;
 INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado)
 VALUES('Director QA',prefijo||'-director@prueba.invalid','fixture','director','activo') RETURNING id INTO director;
 INSERT INTO grado.perfil_docente VALUES(director,'Cursos','Títulos','Temas');
 INSERT INTO grado.sesion_acceso(token_hash,usuario_id) VALUES
 (encode(extensions.digest(ta,'sha256'),'hex'),alumno),
 (encode(extensions.digest(tc,'sha256'),'hex'),comite),
 (encode(extensions.digest(td,'sha256'),'hex'),director);
 INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado)
 SELECT alumno,(SELECT min(id) FROM grado.modalidad),(SELECT min(id) FROM grado.area_experiencia),
 (SELECT min(id) FROM grado.linea_investigacion),'QA textos','Descripción','Objetivos','JSTL','aprobada' RETURNING id INTO v_idea;
 INSERT INTO grado.proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por)
 SELECT id,modalidad_id,titulo,objetivos,descripcion,alumno FROM grado.idea WHERE id=v_idea RETURNING id INTO pid;
 INSERT INTO grado.participante_proyecto(proyecto_id,estudiante_id,nombre_en_pago,correo_en_pago,plaza)
 VALUES(pid,alumno,'Alumno QA',prefijo||'@prueba.invalid',1);
 INSERT INTO grado.datos_pago(proyecto_id) VALUES(pid);
 INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(pid,'pago',CURRENT_TIMESTAMP) RETURNING id INTO fase;
 INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) VALUES(pid,fase,1,alumno) RETURNING id INTO entrega;
 INSERT INTO grado.ciclo_revision(entrega_id,numero) VALUES(entrega,1) RETURNING id INTO ciclo;
 FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
  SELECT * INTO resultado FROM grado.decidir_pago(tc,pid,entrega,'rechazado',vacio);
  IF resultado.ok THEN RAISE EXCEPTION 'Pago aceptó reporte sin contenido'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM grado.revision_entrega WHERE ciclo_id=ciclo) THEN RAISE EXCEPTION 'Creó revisión inválida'; END IF;
 SELECT * INTO resultado FROM grado.decidir_pago(tc,pid,entrega,'rechazado',E'\t Corregir comprobante \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó reporte de Pago válido'; END IF;
 IF (SELECT reporte_respuesta FROM grado.revision_entrega WHERE ciclo_id=ciclo)<>'Corregir comprobante' THEN RAISE EXCEPTION 'No normalizó Pago'; END IF;
 UPDATE grado.datos_pago SET aprobado_por=comite,aprobado_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid;
 INSERT INTO grado.asignacion_proyecto(proyecto_id,docente_id,funcion,asignado_por) VALUES(pid,director,'director',comite);
 UPDATE grado.proyecto_fase SET finalizada_en=CURRENT_TIMESTAMP WHERE id=fase;
 INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en) VALUES(pid,'propuesta_1',CURRENT_TIMESTAMP) RETURNING id INTO fase;
 INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) VALUES(pid,fase,1,alumno) RETURNING id INTO entrega;
 INSERT INTO grado.ciclo_revision(entrega_id,numero) VALUES(entrega,1) RETURNING id INTO ciclo;
 INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id) VALUES(ciclo,'director',director) RETURNING id INTO revision;
 FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
  SELECT * INTO resultado FROM grado.decidir_revision(td,revision,'rechazado',vacio);
  IF resultado.ok THEN RAISE EXCEPTION 'Revisión aceptó reporte sin contenido'; END IF;
 END LOOP;
 IF (SELECT decision FROM grado.revision_entrega WHERE id=revision) IS NOT NULL THEN RAISE EXCEPTION 'Resolvió revisión inválida'; END IF;
 SELECT * INTO resultado FROM grado.decidir_revision(td,revision,'rechazado',E'\t Corregir propuesta \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó reporte de revisión válido'; END IF;
 IF (SELECT reporte_respuesta FROM grado.revision_entrega WHERE id=revision)<>'Corregir propuesta' THEN RAISE EXCEPTION 'No normalizó revisión'; END IF;
 FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
  SELECT * INTO resultado FROM grado.crear_solicitud(ta,pid,'solicitud',vacio,NULL);
  IF resultado.ok THEN RAISE EXCEPTION 'Aceptó solicitud sin motivo'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM grado.solicitud WHERE proyecto_id=pid) THEN RAISE EXCEPTION 'Persistió solicitud inválida'; END IF;
 SELECT * INTO resultado FROM grado.crear_solicitud(ta,pid,'solicitud',E'\t Solicito orientación \r\n',NULL);
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó motivo válido'; END IF;
 SELECT id INTO tramite FROM grado.solicitud WHERE proyecto_id=pid;
 IF (SELECT descripcion FROM grado.solicitud WHERE id=tramite)<>'Solicito orientación' THEN RAISE EXCEPTION 'No normalizó motivo'; END IF;
 FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
  SELECT * INTO resultado FROM grado.decidir_solicitud(tc,tramite,'atendida',vacio);
  IF resultado.ok THEN RAISE EXCEPTION 'Aceptó respuesta sin contenido'; END IF;
 END LOOP;
 IF (SELECT estado FROM grado.solicitud WHERE id=tramite)<>'pendiente' THEN RAISE EXCEPTION 'Resolvió solicitud inválida'; END IF;
 SELECT * INTO resultado FROM grado.decidir_solicitud(tc,tramite,'atendida',E'\t Orientación enviada \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó respuesta válida'; END IF;
 IF (SELECT respuesta FROM grado.respuesta_solicitud WHERE solicitud_id=tramite)<>'Orientación enviada' THEN RAISE EXCEPTION 'No normalizó respuesta'; END IF;
END $test$;
ROLLBACK;
""")
    print('OK: Pago, revisión, motivo y respuesta rechazan cinco variantes vacías sin resolver trámites; textos válidos funcionan. Fixtures revertidos.')


if __name__ == '__main__':
    verificar_textos_tramites()
