-- Persistencia por petición para PersistentValve/DataSourceStore de Tomcat.
-- Aditiva: no cambia cuentas, roles, contraseñas ni la autoactivación del aula.
BEGIN;
CREATE TABLE IF NOT EXISTS grado.sesion_http (
    id varchar(100) NOT NULL,
    aplicacion varchar(255) NOT NULL,
    datos bytea NOT NULL,
    valida char(1) NOT NULL,
    inactividad_maxima integer NOT NULL,
    ultimo_acceso bigint NOT NULL,
    PRIMARY KEY (id, aplicacion)
);
CREATE INDEX IF NOT EXISTS sesion_http_aplicacion ON grado.sesion_http(aplicacion);
ALTER TABLE grado.sesion_http ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON grado.sesion_http FROM PUBLIC;
COMMIT;
