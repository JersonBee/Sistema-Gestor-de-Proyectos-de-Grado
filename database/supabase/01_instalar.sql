-- INSTALACION INICIAL EN SUPABASE SQL EDITOR
-- Ejecutar una sola vez; el esquema grado no debe existir todavia.
-- No elimina datos ni crea cuentas. Si hay un error, se revierte toda la instalacion.
-- Incluye estructura, catalogos y utilidades de hashes/fechas.
-- No incluye aun las operaciones completas del sistema ni un trabajo Cron.
BEGIN;
SET LOCAL TIME ZONE 'America/Bogota';
-- Fuente: database/001_estructura.sql
-- Sistema de Gestión de Proyectos de Grado — PostgreSQL.
-- Ejecutar una vez en una base vacía, con ON_ERROR_STOP habilitado.
-- No contiene usuarios reales ni contraseñas de ejemplo.

CREATE SCHEMA grado;
SET LOCAL search_path TO grado, public;

CREATE TABLE rol (
    codigo text PRIMARY KEY,
    nombre text NOT NULL UNIQUE
);
CREATE TABLE usuario (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rol_codigo text NOT NULL REFERENCES rol(codigo),
    nombre text NOT NULL CHECK (btrim(nombre) <> ''),
    numero_documento text,
    telefono text,
    correo text NOT NULL CHECK (correo = btrim(correo) AND correo LIKE '%@%'),
    contrasena_hash text NOT NULL CHECK (btrim(contrasena_hash) <> ''),
    estado text NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'activo', 'inactivo')),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX usuario_correo_unico ON usuario (lower(correo));
CREATE TABLE area_experiencia (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre text NOT NULL UNIQUE
);
CREATE TABLE perfil_docente (
    usuario_id bigint PRIMARY KEY REFERENCES usuario(id),
    cursos text NOT NULL,
    titulos_academicos text NOT NULL,
    temas_preferencia text NOT NULL
);
CREATE TABLE docente_area (
    docente_id bigint NOT NULL REFERENCES perfil_docente(usuario_id),
    area_id bigint NOT NULL REFERENCES area_experiencia(id),
    PRIMARY KEY (docente_id, area_id)
);
CREATE TABLE modalidad (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo text NOT NULL UNIQUE,
    nombre text NOT NULL UNIQUE
);
CREATE TABLE docente_modalidad (
    docente_id bigint NOT NULL REFERENCES perfil_docente(usuario_id),
    modalidad_id bigint NOT NULL REFERENCES modalidad(id),
    PRIMARY KEY (docente_id, modalidad_id)
);
CREATE TABLE linea_investigacion (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre text NOT NULL UNIQUE
);
CREATE TABLE docente_linea (
    docente_id bigint NOT NULL REFERENCES perfil_docente(usuario_id),
    linea_id bigint NOT NULL REFERENCES linea_investigacion(id),
    PRIMARY KEY (docente_id, linea_id)
);
CREATE TABLE idea (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    autor_id bigint NOT NULL REFERENCES usuario(id),
    modalidad_id bigint NOT NULL REFERENCES modalidad(id),
    area_id bigint NOT NULL REFERENCES area_experiencia(id),
    linea_id bigint NOT NULL REFERENCES linea_investigacion(id),
    titulo text NOT NULL CHECK (btrim(titulo) <> ''),
    descripcion text NOT NULL,
    objetivos text NOT NULL,
    tecnologias text NOT NULL,
    estado text NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE decision_idea (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idea_id bigint NOT NULL REFERENCES idea(id),
    responsable_id bigint NOT NULL REFERENCES usuario(id),
    decision text NOT NULL CHECK (decision IN ('aprobada', 'rechazada')),
    observaciones text,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Coincidencia conjunta de modalidad, área y línea; no basta una sola.
CREATE VIEW docente_apto_idea AS
SELECT i.id AS idea_id, p.usuario_id AS docente_id
FROM idea i
JOIN docente_area a ON a.area_id = i.area_id
JOIN perfil_docente p ON p.usuario_id = a.docente_id
JOIN usuario u ON u.id = p.usuario_id
JOIN docente_modalidad m ON m.docente_id = p.usuario_id AND m.modalidad_id = i.modalidad_id
JOIN docente_linea l ON l.docente_id = p.usuario_id AND l.linea_id = i.linea_id
WHERE u.estado = 'activo' AND u.rol_codigo IN ('director', 'evaluador');

CREATE TABLE proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idea_id bigint NOT NULL REFERENCES idea(id),
    modalidad_id bigint NOT NULL REFERENCES modalidad(id),
    titulo text NOT NULL CHECK (btrim(titulo) <> ''),
    objetivos text NOT NULL,
    descripcion text NOT NULL,
    creado_por bigint NOT NULL REFERENCES usuario(id),
    estado text NOT NULL DEFAULT 'activo'
        CHECK (estado IN ('activo', 'desactivado', 'cancelado', 'finalizado')),
    -- Se establece al iniciar Informe I (fase 4), no al crear el proyecto.
    inicio_vigencia_en timestamptz,
    informe_habilitado_en timestamptz,
    vence_en timestamptz,
    -- Esta aprobación detiene la cancelación por plazo, aunque falten adicionales.
    informe_aprobado_comite_en timestamptz,
    finalizado_por bigint REFERENCES usuario(id),
    finalizado_en timestamptz,
    motivo_desactivacion text,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Fechas efectivas: incluyen cierre del día y ajustes por pausas.
    CHECK ((inicio_vigencia_en IS NULL AND informe_habilitado_en IS NULL AND vence_en IS NULL)
        OR (inicio_vigencia_en IS NOT NULL AND informe_habilitado_en IS NOT NULL
            AND vence_en IS NOT NULL
            AND informe_habilitado_en > inicio_vigencia_en
            AND vence_en > informe_habilitado_en)),
    CHECK (informe_aprobado_comite_en IS NULL OR
        (inicio_vigencia_en IS NOT NULL AND informe_aprobado_comite_en >= inicio_vigencia_en)),
    CHECK ((estado = 'finalizado' AND finalizado_por IS NOT NULL AND finalizado_en IS NOT NULL)
        OR (estado <> 'finalizado' AND finalizado_por IS NULL AND finalizado_en IS NULL))
);
-- La cancelación libera la idea sin borrar su relación histórica.
CREATE UNIQUE INDEX proyecto_reserva_idea
    ON proyecto(idea_id) WHERE estado <> 'cancelado';
CREATE INDEX proyecto_vencimiento ON proyecto(vence_en)
    WHERE estado = 'activo' AND informe_aprobado_comite_en IS NULL;
CREATE TABLE pausa_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    pausado_por bigint NOT NULL REFERENCES usuario(id),
    inicio_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo text NOT NULL CHECK (btrim(motivo) <> ''),
    reanudado_por bigint REFERENCES usuario(id),
    fin_en timestamptz,
    CHECK ((fin_en IS NULL) = (reanudado_por IS NULL)),
    CHECK (fin_en IS NULL OR fin_en >= inicio_en)
);
CREATE UNIQUE INDEX pausa_unica_abierta
    ON pausa_proyecto(proyecto_id) WHERE fin_en IS NULL;
CREATE TABLE participante_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    estudiante_id bigint NOT NULL REFERENCES usuario(id),
    -- Datos presentados en Pago; la FK sigue vinculando la cuenta del estudiante.
    nombre_en_pago text NOT NULL CHECK (btrim(nombre_en_pago) <> ''),
    documento_en_pago text,
    correo_en_pago text NOT NULL CHECK (correo_en_pago LIKE '%@%'),
    telefono_en_pago text,
    plaza smallint NOT NULL CHECK (plaza IN (1, 2)),
    ingreso_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retiro_en timestamptz,
    CHECK (retiro_en IS NULL OR retiro_en >= ingreso_en)
);
-- Las dos plazas limitan la pareja incluso con escrituras concurrentes.
CREATE UNIQUE INDEX participante_plaza_activa
    ON participante_proyecto(proyecto_id, plaza) WHERE retiro_en IS NULL;
CREATE UNIQUE INDEX participante_estudiante_activo
    ON participante_proyecto(estudiante_id) WHERE retiro_en IS NULL;
CREATE TABLE asignacion_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    docente_id bigint NOT NULL REFERENCES perfil_docente(usuario_id),
    funcion text NOT NULL CHECK (funcion IN ('director', 'evaluador')),
    asignado_por bigint NOT NULL REFERENCES usuario(id),
    inicio_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fin_en timestamptz,
    CHECK (fin_en IS NULL OR fin_en >= inicio_en),
    UNIQUE (id, proyecto_id)
);
CREATE UNIQUE INDEX asignacion_funcion_activa
    ON asignacion_proyecto(proyecto_id, funcion) WHERE fin_en IS NULL;
CREATE UNIQUE INDEX asignacion_persona_distinta
    ON asignacion_proyecto(proyecto_id, docente_id) WHERE fin_en IS NULL;

CREATE TABLE fase (
    codigo text PRIMARY KEY,
    nombre text NOT NULL UNIQUE,
    orden smallint NOT NULL UNIQUE CHECK (orden > 0)
);
CREATE TABLE proyecto_fase (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    fase_codigo text NOT NULL REFERENCES fase(codigo),
    -- NULL significa que todavía no hay un resultado; no es un cuarto estado.
    estado text CHECK (estado IN ('aprobado', 'rechazado', 'aplicado')),
    iniciada_en timestamptz,
    finalizada_en timestamptz,
    UNIQUE (proyecto_id, fase_codigo),
    UNIQUE (id, proyecto_id),
    CHECK (finalizada_en IS NULL OR
        (iniciada_en IS NOT NULL AND finalizada_en >= iniciada_en))
);
CREATE UNIQUE INDEX proyecto_una_fase_en_curso
    ON proyecto_fase(proyecto_id)
    WHERE iniciada_en IS NOT NULL AND finalizada_en IS NULL;
CREATE TABLE tipo_documento (
    codigo text PRIMARY KEY,
    nombre text NOT NULL UNIQUE
);
CREATE TABLE documento (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    proyecto_fase_id bigint NOT NULL,
    tipo_codigo text NOT NULL REFERENCES tipo_documento(codigo),
    etiqueta text NOT NULL DEFAULT '',
    CHECK (tipo_codigo <> 'adicional' OR btrim(etiqueta) <> ''),
    UNIQUE (proyecto_fase_id, tipo_codigo, etiqueta),
    UNIQUE (id, proyecto_id),
    FOREIGN KEY (proyecto_fase_id, proyecto_id)
        REFERENCES proyecto_fase(id, proyecto_id)
);
CREATE UNIQUE INDEX documento_institucional_unico
    ON documento(proyecto_fase_id, tipo_codigo) WHERE tipo_codigo <> 'adicional';
CREATE TABLE documento_version (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento_id bigint NOT NULL REFERENCES documento(id),
    numero integer NOT NULL CHECK (numero > 0),
    url text NOT NULL CHECK (url ~* '^https?://[^[:space:]]+$'),
    registrado_por bigint NOT NULL REFERENCES usuario(id),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (documento_id, numero),
    UNIQUE (id, documento_id)
);
-- El conjunto fija las versiones exactas sometidas a revisión.
-- Propuesta I/II e Informe I/II comparten la entrega; no duplican archivos.
CREATE TABLE entrega_revision (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    fase_origen_id bigint NOT NULL,
    numero integer NOT NULL CHECK (numero > 0),
    presentada_por bigint NOT NULL REFERENCES usuario(id),
    presentada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (fase_origen_id, numero),
    UNIQUE (id, proyecto_id),
    FOREIGN KEY (fase_origen_id, proyecto_id) REFERENCES proyecto_fase(id, proyecto_id)
);
CREATE TABLE entrega_documento_version (
    entrega_id bigint NOT NULL,
    proyecto_id bigint NOT NULL,
    documento_id bigint NOT NULL,
    version_id bigint NOT NULL,
    PRIMARY KEY (entrega_id, documento_id),
    FOREIGN KEY (entrega_id, proyecto_id) REFERENCES entrega_revision(id, proyecto_id),
    FOREIGN KEY (documento_id, proyecto_id) REFERENCES documento(id, proyecto_id),
    FOREIGN KEY (version_id, documento_id) REFERENCES documento_version(id, documento_id)
);
CREATE TABLE ciclo_revision (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entrega_id bigint NOT NULL REFERENCES entrega_revision(id),
    numero integer NOT NULL CHECK (numero > 0),
    iniciado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finalizado_en timestamptz,
    UNIQUE (entrega_id, numero),
    CHECK (finalizado_en IS NULL OR finalizado_en >= iniciado_en)
);
CREATE UNIQUE INDEX ciclo_revision_abierto
    ON ciclo_revision(entrega_id) WHERE finalizado_en IS NULL;
CREATE TABLE revision_entrega (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ciclo_id bigint NOT NULL REFERENCES ciclo_revision(id),
    etapa text NOT NULL CHECK (etapa IN ('director', 'evaluador', 'comite')),
    responsable_id bigint NOT NULL REFERENCES usuario(id),
    asignada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    limite_en timestamptz,
    decision text CHECK (decision IN ('aprobado', 'rechazado', 'aplicado')),
    reporte_respuesta text,
    decidida_en timestamptz,
    UNIQUE (ciclo_id, etapa),
    CHECK (limite_en IS NULL OR limite_en > asignada_en),
    CHECK ((decision IS NULL AND decidida_en IS NULL)
        OR (decision IS NOT NULL AND decidida_en IS NOT NULL)),
    CHECK (decidida_en IS NULL OR decidida_en >= asignada_en),
    CHECK (decision IS NULL OR decision = 'aplicado'
        OR length(btrim(coalesce(reporte_respuesta, ''))) > 0)
);
CREATE TABLE plazo_correccion (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    revision_id bigint NOT NULL UNIQUE REFERENCES revision_entrega(id),
    inicio_en timestamptz NOT NULL,
    limite_en timestamptz NOT NULL CHECK (limite_en > inicio_en),
    entrega_reenvio_id bigint UNIQUE REFERENCES entrega_revision(id)
);

CREATE TABLE datos_pago (
    proyecto_id bigint PRIMARY KEY REFERENCES proyecto(id),
    director_propuesto_id bigint REFERENCES perfil_docente(usuario_id),
    aprobado_por bigint REFERENCES usuario(id),
    aprobado_en timestamptz,
    CHECK ((aprobado_por IS NULL) = (aprobado_en IS NULL))
    -- El comprobante es un documento; título, objetivos y descripción en proyecto.
);
CREATE TABLE entrega_final (
    proyecto_id bigint PRIMARY KEY REFERENCES proyecto(id),
    tipo_licencia text,
    repositorio_url text CHECK (repositorio_url ~* '^https?://[^[:space:]]+$'),
    repositorio_registrado_por bigint REFERENCES usuario(id),
    repositorio_registrado_en timestamptz,
    CHECK ((repositorio_url IS NULL AND repositorio_registrado_por IS NULL
        AND repositorio_registrado_en IS NULL) OR
        (repositorio_url IS NOT NULL AND repositorio_registrado_por IS NOT NULL
        AND repositorio_registrado_en IS NOT NULL))
    -- Manual y evidencia: documentos versionados de la fase Final.
);
CREATE TABLE solicitud (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    solicitante_id bigint NOT NULL REFERENCES usuario(id),
    tipo text NOT NULL CHECK (tipo IN
        ('cambio_director', 'cambio_evaluador', 'retiro', 'reclamo', 'queja', 'solicitud')),
    descripcion text NOT NULL CHECK (btrim(descripcion) <> ''),
    docente_preferido_id bigint REFERENCES perfil_docente(usuario_id),
    estado text NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'aprobada', 'rechazada', 'atendida')),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (tipo NOT IN ('cambio_director', 'cambio_evaluador')
        OR docente_preferido_id IS NOT NULL)
);
CREATE TABLE respuesta_solicitud (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id bigint NOT NULL REFERENCES solicitud(id),
    responsable_id bigint NOT NULL REFERENCES usuario(id),
    estado_resultante text NOT NULL
        CHECK (estado_resultante IN ('pendiente', 'aprobada', 'rechazada', 'atendida')),
    respuesta text NOT NULL CHECK (btrim(respuesta) <> ''),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE acta (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero text NOT NULL UNIQUE,
    fecha date NOT NULL,
    descripcion text NOT NULL,
    detalles text NOT NULL,
    creada_por bigint NOT NULL REFERENCES usuario(id),
    aprobada_por bigint REFERENCES usuario(id),
    aprobada_en timestamptz,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ((aprobada_por IS NULL) = (aprobada_en IS NULL))
);
CREATE TABLE acta_proyecto (
    acta_id bigint NOT NULL REFERENCES acta(id),
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    PRIMARY KEY (acta_id, proyecto_id)
);
CREATE TABLE mensaje (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint NOT NULL REFERENCES proyecto(id),
    remitente_id bigint NOT NULL REFERENCES usuario(id),
    destinatario_id bigint NOT NULL REFERENCES usuario(id),
    contenido text NOT NULL CHECK (btrim(contenido) <> ''),
    enviado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leido_en timestamptz,
    CHECK (remitente_id <> destinatario_id),
    CHECK (leido_en IS NULL OR leido_en >= enviado_en)
);
CREATE TABLE evento_auditoria (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proyecto_id bigint REFERENCES proyecto(id),
    actor_id bigint REFERENCES usuario(id),
    origen text NOT NULL CHECK (origen IN ('usuario', 'sistema')),
    accion text NOT NULL,
    entidad text NOT NULL,
    entidad_id bigint NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ((origen = 'usuario' AND actor_id IS NOT NULL)
        OR (origen = 'sistema' AND actor_id IS NULL))
);
CREATE TABLE notificacion (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evento_id bigint NOT NULL REFERENCES evento_auditoria(id),
    destinatario_id bigint NOT NULL REFERENCES usuario(id),
    asunto text NOT NULL,
    cuerpo text NOT NULL,
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leido_en timestamptz,
    UNIQUE (evento_id, destinatario_id),
    CHECK (leido_en IS NULL OR leido_en >= creado_en)
);

CREATE FUNCTION actualizar_fecha_modificacion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.actualizado_en := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
CREATE TRIGGER usuario_actualizacion BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();
CREATE TRIGGER proyecto_actualizacion BEFORE UPDATE ON proyecto
    FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Simplificación expresa del aula: autoactivación de estudiantes y docentes.
CREATE FUNCTION autoactivar_registro() RETURNS trigger
LANGUAGE plpgsql SET search_path = grado, pg_temp AS $$
BEGIN
    IF NEW.rol_codigo IN ('estudiante', 'director', 'evaluador') AND NEW.estado = 'pendiente' THEN
        NEW.estado := 'activo';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER usuario_autoactivacion BEFORE INSERT ON usuario
    FOR EACH ROW EXECUTE FUNCTION autoactivar_registro();

-- Valida el rol del responsable registrado; autenticar al actor sigue siendo
-- responsabilidad de la operación de cierre en la aplicación.
CREATE FUNCTION validar_responsable_cierre() RETURNS trigger
LANGUAGE plpgsql SET search_path = grado, pg_temp AS $$
BEGIN
    IF NEW.estado = 'finalizado' AND NOT EXISTS (
        SELECT 1 FROM usuario WHERE id = NEW.finalizado_por
            AND rol_codigo = 'comite' AND estado = 'activo'
    ) THEN
        RAISE EXCEPTION 'Solo el Comité puede figurar como responsable de finalizar el proyecto.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER proyecto_responsable_cierre BEFORE INSERT OR UPDATE ON proyecto
    FOR EACH ROW EXECUTE FUNCTION validar_responsable_cierre();

CREATE FUNCTION comprobar_pago_antes_asignacion() RETURNS trigger
LANGUAGE plpgsql SET search_path = grado, pg_temp AS $$
BEGIN
    IF NEW.fin_en IS NULL AND NOT EXISTS (
        SELECT 1 FROM datos_pago dp
        JOIN proyecto p ON p.id = dp.proyecto_id
        JOIN idea i ON i.id = p.idea_id
        JOIN usuario u ON u.id = dp.aprobado_por
        WHERE dp.proyecto_id = NEW.proyecto_id AND dp.aprobado_en IS NOT NULL
            AND u.rol_codigo = 'comite' AND i.estado = 'aprobada' AND p.estado = 'activo'
    ) THEN
        RAISE EXCEPTION 'La asignación requiere pago e idea aprobados por el Comité y proyecto activo.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER asignacion_pago_previo BEFORE INSERT OR UPDATE ON asignacion_proyecto
    FOR EACH ROW EXECUTE FUNCTION comprobar_pago_antes_asignacion();

CREATE INDEX idea_busqueda ON idea(estado, modalidad_id);
CREATE INDEX decision_idea_historial ON decision_idea(idea_id, creado_en);
CREATE INDEX proyecto_busqueda ON proyecto(estado, modalidad_id, creado_en);
CREATE INDEX proyecto_idea ON proyecto(idea_id);
CREATE INDEX participante_busqueda ON participante_proyecto(estudiante_id, proyecto_id);
CREATE INDEX asignacion_docente ON asignacion_proyecto(docente_id, funcion, proyecto_id);
CREATE INDEX fase_estado ON proyecto_fase(fase_codigo, estado);
CREATE INDEX revision_pendiente ON revision_entrega(responsable_id, limite_en)
    WHERE decision IS NULL;
CREATE INDEX solicitud_bandeja ON solicitud(estado, proyecto_id, creado_en);
CREATE INDEX respuesta_historial ON respuesta_solicitud(solicitud_id, creado_en);
CREATE INDEX mensaje_bandeja ON mensaje(destinatario_id, enviado_en);
CREATE INDEX mensaje_proyecto ON mensaje(proyecto_id, enviado_en);
CREATE INDEX auditoria_proyecto ON evento_auditoria(proyecto_id, creado_en, id);
CREATE INDEX auditoria_entidad ON evento_auditoria(entidad, entidad_id, creado_en);
CREATE INDEX notificacion_bandeja ON notificacion(destinatario_id, creado_en);
CREATE INDEX notificacion_pendiente ON notificacion(destinatario_id, creado_en)
    WHERE leido_en IS NULL;

-- Fuente: database/002_catalogos.sql
SET LOCAL search_path TO grado, public;
INSERT INTO rol (codigo, nombre) VALUES
    ('estudiante', 'Estudiante'),
    ('director', 'Director'),
    ('evaluador', 'Evaluador'),
    ('comite', 'Comité / Coordinador'),
    ('secretaria', 'Secretaría');
-- Visitante no es una cuenta; Sistema no es un usuario con credenciales.
INSERT INTO modalidad (codigo, nombre) VALUES
    ('desarrollo_software', 'Desarrollo de software'),
    ('monografia', 'Monografía'),
    ('emprendimiento', 'Emprendimiento'),
    ('proyecto_investigacion', 'Proyecto de investigación');
INSERT INTO fase (codigo, nombre, orden) VALUES
    ('pago', 'Pago', 1),
    ('propuesta_1', 'Propuesta I', 2),
    ('propuesta_2', 'Propuesta II', 3),
    ('informe_1', 'Informe I', 4),
    ('informe_2', 'Informe II', 5),
    ('final', 'Final', 6);
INSERT INTO tipo_documento (codigo, nombre) VALUES
    ('comprobante_pago', 'Comprobante de pago'),
    ('f_dc_124', 'F-DC-124'),
    ('f_dc_125', 'F-DC-125'),
    ('f_dc_129', 'F-DC-129'),
    ('turnitin', 'Reporte Turnitin'),
    ('manual_usuario', 'Manual de usuario'),
    ('evidencia_publicacion', 'Evidencia de publicación en repositorio'),
    ('adicional', 'Documento adicional opcional');
-- Se acepta cualquier enlace web, sin restricciones de extensión o proveedor.

-- Fuente: database/004_utilidades.sql
-- Después de 001 y 002. No crea cuentas ni activa tareas Cron.

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
-- No reubicar una extensión existente ni afectar componentes de Supabase.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
        WHERE e.extname = 'pgcrypto' AND n.nspname = 'extensions') THEN
        RAISE EXCEPTION 'pgcrypto está en otro esquema; adaptar las referencias antes de ejecutar este archivo.';
    END IF;
END;
$$;

CREATE FUNCTION grado.crear_hash_contrasena(contrasena text) RETURNS text
LANGUAGE plpgsql STRICT SECURITY INVOKER
SET search_path = grado, extensions, pg_temp AS $$
BEGIN
    -- bcrypt limita a 72 bytes; no permitir truncamiento silencioso.
    IF octet_length(contrasena) = 0 OR octet_length(contrasena) > 72 THEN
        RAISE EXCEPTION 'La contraseña debe tener entre 1 y 72 bytes UTF-8.';
    END IF;
    RETURN extensions.crypt(contrasena, extensions.gen_salt('bf', 12));
END;
$$;
CREATE FUNCTION grado.verificar_hash_contrasena(contrasena text, hash_guardado text)
RETURNS boolean LANGUAGE plpgsql STRICT SECURITY INVOKER
SET search_path = grado, extensions, pg_temp AS $$
BEGIN
    IF octet_length(contrasena) = 0 OR octet_length(contrasena) > 72
        OR hash_guardado !~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$' THEN
        RETURN false;
    END IF;
    RETURN extensions.crypt(contrasena, hash_guardado) = hash_guardado;
END;
$$;
-- Conceder EXECUTE exclusivamente al rol de conexión de la aplicación al crearlo.
REVOKE ALL ON FUNCTION grado.crear_hash_contrasena(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION grado.verificar_hash_contrasena(text, text) FROM PUBLIC;

CREATE FUNCTION grado.limite_dias_calendario(inicio timestamptz, dias integer)
RETURNS timestamptz LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER
SET search_path = grado, pg_temp AS $$
BEGIN
    IF dias < 0 THEN RAISE EXCEPTION 'El plazo no puede ser negativo.'; END IF;
    -- El día del evento es día cero; vence a las 23:59 del último día en Bogotá.
    RETURN (((inicio AT TIME ZONE 'America/Bogota')::date + dias)
        + time '23:59:00') AT TIME ZONE 'America/Bogota';
END;
$$;
CREATE FUNCTION grado.habilitacion_informe(inicio timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER
SET search_path = grado, pg_temp AS $$
    SELECT (((inicio AT TIME ZONE 'America/Bogota')::date + 90)
        + time '00:00:00') AT TIME ZONE 'America/Bogota';
$$;
COMMIT;
SELECT 'Instalacion completada' AS resultado,
    (SELECT count(*) FROM information_schema.tables
     WHERE table_schema = 'grado' AND table_type = 'BASE TABLE') AS tablas,
    (SELECT count(*) FROM grado.rol) AS roles,
    (SELECT count(*) FROM grado.modalidad) AS modalidades,
    (SELECT count(*) FROM grado.fase) AS fases;
