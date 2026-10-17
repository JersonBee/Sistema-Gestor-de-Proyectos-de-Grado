-- Ejecutar después de 001 y 002 en una base de desarrollo.
-- Todos los datos de prueba se revierten. Las secuencias pueden avanzar.
BEGIN;
SET LOCAL search_path TO grado, public;
DO $$
DECLARE
    estudiante bigint;
    docente bigint;
    comite bigint;
    modalidad_prueba bigint;
    area_prueba bigint;
    linea bigint;
    idea_prueba bigint;
    otra_idea bigint;
    proyecto_prueba bigint;
    otro_proyecto bigint;
    fase_prueba bigint;
    documento_prueba bigint;
    version_prueba bigint;
    entrega_prueba bigint;
    ciclo_prueba bigint;
BEGIN
    INSERT INTO usuario(rol_codigo, nombre, correo, contrasena_hash)
    VALUES ('estudiante', 'Estudiante de prueba', 'estudiante@example.invalid',
        'MARCADOR_NO_AUTENTICABLE') RETURNING id INTO estudiante;
    IF (SELECT estado FROM usuario WHERE id = estudiante) <> 'activo' THEN
        RAISE EXCEPTION 'Fallo: el registro estudiantil no se autoactivó';
    END IF;
    INSERT INTO usuario(rol_codigo, nombre, correo, contrasena_hash)
    VALUES ('director', 'Docente de prueba', 'docente@example.invalid',
        'MARCADOR_NO_AUTENTICABLE') RETURNING id INTO docente;
    IF (SELECT estado FROM usuario WHERE id = docente) <> 'activo' THEN
        RAISE EXCEPTION 'Fallo: el registro docente no se autoactivó';
    END IF;
    INSERT INTO usuario(rol_codigo, nombre, correo, contrasena_hash, estado)
    VALUES ('comite', 'Comité de prueba', 'comite@example.invalid',
        'MARCADOR_NO_AUTENTICABLE', 'activo') RETURNING id INTO comite;
    BEGIN
        INSERT INTO usuario(rol_codigo, nombre, correo, contrasena_hash)
        VALUES ('estudiante', 'Duplicado', 'ESTUDIANTE@example.invalid', 'MARCADOR');
        RAISE EXCEPTION 'Fallo: permitió correo duplicado con otras mayúsculas';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    INSERT INTO area_experiencia(nombre) VALUES ('Área de prueba') RETURNING id INTO area_prueba;
    INSERT INTO perfil_docente VALUES (docente, 'Cursos', 'Títulos', 'Temas');
    INSERT INTO docente_area(docente_id, area_id) VALUES (docente, area_prueba);
    SELECT id INTO STRICT modalidad_prueba FROM modalidad
        WHERE codigo = 'desarrollo_software';
    INSERT INTO linea_investigacion(nombre) VALUES ('Línea de prueba') RETURNING id INTO linea;
    INSERT INTO docente_modalidad(docente_id, modalidad_id) VALUES (docente, modalidad_prueba);
    INSERT INTO docente_linea(docente_id, linea_id) VALUES (docente, linea);
    INSERT INTO idea(autor_id, modalidad_id, area_id, linea_id, titulo, descripcion, objetivos, tecnologias, estado)
    VALUES (docente, modalidad_prueba, area_prueba, linea, 'Idea de prueba', 'Descripción', 'Objetivos', 'Tecnologías', 'aprobada')
    RETURNING id INTO idea_prueba;
    IF NOT EXISTS (SELECT 1 FROM docente_apto_idea
        WHERE idea_id = idea_prueba AND docente_id = docente) THEN
        RAISE EXCEPTION 'Fallo: no encontró docente con modalidad, área y línea coincidentes';
    END IF;
    INSERT INTO idea(autor_id, modalidad_id, area_id, linea_id, titulo, descripcion, objetivos, tecnologias, estado)
    VALUES (docente, modalidad_prueba, area_prueba, linea, 'Otra idea', 'Descripción', 'Objetivos', 'Tecnologías', 'aprobada')
    RETURNING id INTO otra_idea;
    INSERT INTO proyecto(idea_id, modalidad_id, titulo, objetivos, descripcion, creado_por)
    VALUES (idea_prueba, modalidad_prueba, 'Proyecto de prueba', 'Objetivos', 'Descripción', estudiante)
    RETURNING id INTO proyecto_prueba;
    INSERT INTO proyecto(idea_id, modalidad_id, titulo, objetivos, descripcion, creado_por)
    VALUES (otra_idea, modalidad_prueba, 'Otro proyecto', 'Objetivos', 'Descripción', estudiante)
    RETURNING id INTO otro_proyecto;
    BEGIN
        INSERT INTO proyecto(idea_id, modalidad_id, titulo, objetivos, descripcion, creado_por)
        VALUES (idea_prueba, modalidad_prueba, 'Idea ya reservada', 'Objetivos', 'Descripción', estudiante);
        RAISE EXCEPTION 'Fallo: permitió reutilizar una idea reservada';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    INSERT INTO participante_proyecto(proyecto_id, estudiante_id, plaza, nombre_en_pago, correo_en_pago)
    VALUES (proyecto_prueba, estudiante, 1, 'Estudiante de prueba', 'estudiante@example.invalid');
    BEGIN
        INSERT INTO participante_proyecto(proyecto_id, estudiante_id, plaza, nombre_en_pago, correo_en_pago)
        VALUES (proyecto_prueba, estudiante, 2, 'Estudiante de prueba', 'estudiante@example.invalid');
        RAISE EXCEPTION 'Fallo: duplicó un integrante activo';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO participante_proyecto(proyecto_id, estudiante_id, plaza, nombre_en_pago, correo_en_pago)
        VALUES (otro_proyecto, estudiante, 1, 'Estudiante de prueba', 'estudiante@example.invalid');
        RAISE EXCEPTION 'Fallo: permitió al estudiante dos proyectos simultáneos';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO participante_proyecto(proyecto_id, estudiante_id, plaza, nombre_en_pago, correo_en_pago)
        VALUES (proyecto_prueba, estudiante, 3, 'Estudiante de prueba', 'estudiante@example.invalid');
        RAISE EXCEPTION 'Fallo: permitió una tercera plaza';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE proyecto SET estado = 'cancelado' WHERE id = otro_proyecto;
    INSERT INTO proyecto(idea_id, modalidad_id, titulo, objetivos, descripcion, creado_por)
    VALUES (otra_idea, modalidad_prueba, 'Reutilización de idea liberada', 'Objetivos', 'Descripción', estudiante);
    BEGIN
        INSERT INTO asignacion_proyecto(proyecto_id, docente_id, funcion, asignado_por)
        VALUES (proyecto_prueba, docente, 'director', comite);
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Fallo: asignó docentes antes de aprobar Pago';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    -- El flujo real registra esta aprobación y su revisión antes de asignar docentes.
    INSERT INTO datos_pago(proyecto_id, aprobado_por, aprobado_en)
    VALUES (proyecto_prueba, comite, CURRENT_TIMESTAMP);
    INSERT INTO asignacion_proyecto(proyecto_id, docente_id, funcion, asignado_por)
    VALUES (proyecto_prueba, docente, 'director', comite);
    BEGIN
        INSERT INTO asignacion_proyecto(proyecto_id, docente_id, funcion, asignado_por)
        VALUES (proyecto_prueba, docente, 'evaluador', comite);
        RAISE EXCEPTION 'Fallo: permitió que director y evaluador fueran la misma persona';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO asignacion_proyecto(proyecto_id, docente_id, funcion, asignado_por)
        VALUES (proyecto_prueba, docente, 'director', comite);
        RAISE EXCEPTION 'Fallo: permitió dos directores vigentes';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    INSERT INTO proyecto_fase(proyecto_id, fase_codigo, iniciada_en)
    VALUES (proyecto_prueba, 'propuesta_1', CURRENT_TIMESTAMP) RETURNING id INTO fase_prueba;
    INSERT INTO documento(proyecto_id, proyecto_fase_id, tipo_codigo, etiqueta)
    VALUES (proyecto_prueba, fase_prueba, 'adicional', 'Anexo solicitado por director'),
           (proyecto_prueba, fase_prueba, 'adicional', 'Anexo solicitado por Comité');
    BEGIN
        INSERT INTO documento(proyecto_id, proyecto_fase_id, tipo_codigo)
        VALUES (otro_proyecto, fase_prueba, 'f_dc_124');
        RAISE EXCEPTION 'Fallo: vinculó un documento con la fase de otro proyecto';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    INSERT INTO documento(proyecto_id, proyecto_fase_id, tipo_codigo)
    VALUES (proyecto_prueba, fase_prueba, 'f_dc_124') RETURNING id INTO documento_prueba;
    -- Ahora son válidos enlaces sin extensión, por decisión del usuario.
    INSERT INTO documento_version(documento_id, numero, url, registrado_por)
    VALUES (documento_prueba, 1, 'https://example.invalid/documento/compartido', estudiante)
    RETURNING id INTO version_prueba;
    INSERT INTO entrega_revision(proyecto_id, fase_origen_id, numero, presentada_por)
    VALUES (proyecto_prueba, fase_prueba, 1, estudiante) RETURNING id INTO entrega_prueba;
    INSERT INTO entrega_documento_version(entrega_id, proyecto_id, documento_id, version_id)
    VALUES (entrega_prueba, proyecto_prueba, documento_prueba, version_prueba);
    INSERT INTO ciclo_revision(entrega_id, numero) VALUES (entrega_prueba, 1)
    RETURNING id INTO ciclo_prueba;
    BEGIN
        INSERT INTO revision_entrega(ciclo_id, etapa, responsable_id, decision, decidida_en)
        VALUES (ciclo_prueba, 'director', docente, 'aprobado', CURRENT_TIMESTAMP);
        RAISE EXCEPTION 'Fallo: aceptó aprobación sin reporte';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    INSERT INTO revision_entrega(ciclo_id, etapa, responsable_id, decision, reporte_respuesta, decidida_en)
    VALUES (ciclo_prueba, 'director', docente, 'aprobado', 'Formato conforme.', CURRENT_TIMESTAMP);
    UPDATE proyecto SET inicio_vigencia_en = CURRENT_TIMESTAMP,
        informe_habilitado_en = CURRENT_TIMESTAMP + interval '90 days',
        vence_en = CURRENT_TIMESTAMP + interval '180 days' WHERE id = proyecto_prueba;
    BEGIN
        UPDATE proyecto SET vence_en = inicio_vigencia_en
        WHERE id = proyecto_prueba;
        RAISE EXCEPTION 'Fallo: permitió un vencimiento anterior a la habilitación del informe';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO evento_auditoria(origen, accion, entidad, entidad_id)
        VALUES ('usuario', 'prueba', 'proyecto', proyecto_prueba);
        RAISE EXCEPTION 'Fallo: aceptó auditoría humana sin actor';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF (SELECT count(*) FROM fase) <> 6 THEN
        RAISE EXCEPTION 'Fallo: se esperaban seis fases';
    END IF;
    BEGIN
        UPDATE proyecto SET estado = 'finalizado', finalizado_por = docente,
            finalizado_en = CURRENT_TIMESTAMP WHERE id = proyecto_prueba;
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Fallo: permitió cierre por un docente';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    UPDATE proyecto SET estado = 'finalizado', finalizado_por = comite,
        finalizado_en = CURRENT_TIMESTAMP WHERE id = proyecto_prueba;
    RAISE NOTICE 'Verificaciones de integridad completadas. Se revertirán los datos de prueba.';
END;
$$;
ROLLBACK;
