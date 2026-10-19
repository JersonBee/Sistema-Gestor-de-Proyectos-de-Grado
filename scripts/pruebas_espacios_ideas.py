"""Ideas y decisiones sin contenido: transacción revertida en grado_pruebas."""
from pruebas_acceso import sql


def verificar_espacios_ideas():
    assert sql('SELECT current_database();').strip() == 'grado_pruebas'
    sql(r"""
BEGIN;
DO $test$
DECLARE alumno bigint; comite bigint; modalidad bigint; v_idea bigint;
    resultado record; campo text; datos jsonb; total bigint;
    prefijo text := 'qa-ideas-' || txid_current();
    token text := repeat(md5(random()::text),2); token_comite text := repeat(md5(random()::text),2);
BEGIN
 IF current_database()<>'grado_pruebas' THEN RAISE EXCEPTION 'Solo pruebas locales'; END IF;
 INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado)
 VALUES('Alumno QA',prefijo||'@prueba.invalid','hash de fixture','estudiante','activo') RETURNING id INTO alumno;
 INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado)
 VALUES('Comité QA',prefijo||'-comite@prueba.invalid','hash de fixture','comite','activo') RETURNING id INTO comite;
 INSERT INTO grado.sesion_acceso(token_hash,usuario_id) VALUES
 (encode(extensions.digest(token,'sha256'),'hex'),alumno),
 (encode(extensions.digest(token_comite,'sha256'),'hex'),comite);
 SELECT min(id) INTO modalidad FROM grado.modalidad;
 datos:=jsonb_build_object('titulo','Idea QA','descripcion','Descripción QA',
 'objetivos','Objetivos QA','tecnologias','JSTL','area',prefijo,'linea',prefijo,'modalidad',modalidad);
 SELECT count(*) INTO total FROM grado.idea;
 FOREACH campo IN ARRAY ARRAY['titulo','descripcion','objetivos','tecnologias','area','linea'] LOOP
  SELECT * INTO resultado FROM grado.proponer_idea(token,jsonb_set(datos,ARRAY[campo],to_jsonb(E'\t\r\n'::text)));
  IF resultado.ok THEN RAISE EXCEPTION 'Aceptó idea con campo vacío: %',campo; END IF;
 END LOOP;
 IF (SELECT count(*) FROM grado.idea)<>total THEN RAISE EXCEPTION 'Persistió ideas inválidas'; END IF;
 SELECT * INTO resultado FROM grado.proponer_idea(token,datos||jsonb_build_object('titulo',E'\t Idea QA \r\n'));
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó idea válida: %',resultado.mensaje; END IF;
 v_idea:=resultado.recurso_id;
 IF (SELECT titulo FROM grado.idea WHERE id=v_idea)<>'Idea QA' THEN RAISE EXCEPTION 'No normalizó el título'; END IF;
 SELECT * INTO resultado FROM grado.decidir_idea(token_comite,v_idea,'rechazada',E'\t\r\n');
 IF resultado.ok OR (SELECT estado FROM grado.idea WHERE id=v_idea)<>'pendiente' THEN
  RAISE EXCEPTION 'Aceptó decisión sin observaciones';
 END IF;
 SELECT * INTO resultado FROM grado.decidir_idea(token_comite,v_idea,'aprobada',E'\t Aprobada para iniciar \r\n');
 IF NOT resultado.ok THEN RAISE EXCEPTION 'Rechazó decisión válida'; END IF;
 IF (SELECT observaciones FROM grado.decision_idea WHERE idea_id=v_idea)<>'Aprobada para iniciar' THEN
  RAISE EXCEPTION 'No normalizó las observaciones';
 END IF;
END $test$;
ROLLBACK;
""")
    print('OK: seis campos obligatorios y observaciones rechazan espacios; idea y decisión válidas funcionan. Fixtures revertidos.')


if __name__ == '__main__':
    verificar_espacios_ideas()
