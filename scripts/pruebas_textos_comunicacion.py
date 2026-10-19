"""Mensajes y actas obligatorios; transacción local revertida."""
from pruebas_acceso import sql


def verificar_textos_comunicacion():
    assert sql('SELECT current_database();').strip() == 'grado_pruebas'
    sql(r"""
BEGIN;
DO $test$
DECLARE alumno bigint; comite bigint; director bigint; v_idea bigint; pid bigint;
    resultado record; vacio text; campo text; numero_acta text; descripcion_acta text; detalles_acta text;
    prefijo text := 'qa-comunicacion-' || txid_current();
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
 UPDATE grado.datos_pago SET aprobado_por=comite,aprobado_en=CURRENT_TIMESTAMP WHERE proyecto_id=pid;
 INSERT INTO grado.asignacion_proyecto(proyecto_id,docente_id,funcion,asignado_por) VALUES(pid,director,'director',comite);

 FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
  SELECT * INTO resultado FROM grado.enviar_mensaje(ta,pid,director,vacio);
  IF resultado.ok THEN RAISE EXCEPTION 'Aceptó mensaje vacío'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM grado.mensaje WHERE proyecto_id=pid) THEN RAISE EXCEPTION 'Persistió mensaje vacío'; END IF;
 SELECT * INTO resultado FROM grado.enviar_mensaje(ta,pid,director,E'\t Hola director\nNecesito orientación. \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó mensaje válido'; END IF;
 IF (SELECT contenido FROM grado.mensaje WHERE proyecto_id=pid)<>E'Hola director\nNecesito orientación.' THEN RAISE EXCEPTION 'Alteró contenido interior del mensaje'; END IF;
 FOREACH campo IN ARRAY ARRAY['numero','descripcion','detalles'] LOOP
  FOREACH vacio IN ARRAY ARRAY['', '   ', E'\t', E'\r\n', E' \t\r\n '] LOOP
   numero_acta:=CASE WHEN campo='numero' THEN vacio ELSE prefijo END;
   descripcion_acta:=CASE WHEN campo='descripcion' THEN vacio ELSE 'Sesión de seguimiento' END;
   detalles_acta:=CASE WHEN campo='detalles' THEN vacio ELSE 'Se revisaron avances.' END;
   SELECT * INTO resultado FROM grado.crear_acta(tc,pid,numero_acta,'2026-10-19',descripcion_acta,detalles_acta);
   IF resultado.ok THEN RAISE EXCEPTION 'Aceptó acta con campo vacío: %',campo; END IF;
  END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM grado.acta_proyecto WHERE proyecto_id=pid) THEN RAISE EXCEPTION 'Persistió acta inválida'; END IF;
 SELECT * INTO resultado FROM grado.crear_acta(tc,pid,prefijo,'2026-02-30','Sesión','Detalles');
 IF resultado.ok THEN RAISE EXCEPTION 'Aceptó fecha imposible'; END IF;
 SELECT * INTO resultado FROM grado.crear_acta(tc,pid,E'\t '||prefijo||E' \n','2026-10-19',E'\t Sesión de seguimiento \r\n',E'\t Primer punto\nSegundo punto \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó acta válida: %',resultado.mensaje; END IF;
 IF NOT EXISTS(SELECT 1 FROM grado.acta WHERE id=resultado.recurso_id AND numero=prefijo AND descripcion='Sesión de seguimiento' AND detalles=E'Primer punto\nSegundo punto') THEN RAISE EXCEPTION 'Normalización incorrecta del acta'; END IF;
 SELECT * INTO resultado FROM grado.aprobar_acta(tc,resultado.recurso_id);
 IF NOT resultado.ok THEN RAISE EXCEPTION 'No aprobó acta válida'; END IF;
END $test$;
ROLLBACK;
""")
    print('OK: mensajes y tres campos de acta rechazan cinco variantes vacías; textos válidos conservan saltos interiores, fecha inválida se rechaza y aprobación funciona. Fixtures revertidos.')


if __name__ == '__main__':
    verificar_textos_comunicacion()
