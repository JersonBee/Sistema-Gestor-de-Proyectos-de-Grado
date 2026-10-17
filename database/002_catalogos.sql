BEGIN;
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
COMMIT;
