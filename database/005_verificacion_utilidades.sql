-- Ejecutar después de 004 con el rol propietario. Sin datos persistentes.
BEGIN;
DO $$
DECLARE hash_uno text; hash_dos text; esperado timestamptz;
BEGIN
    -- Cadena sintética; no pertenece a una cuenta ni se registra en la salida.
    hash_uno := grado.crear_hash_contrasena('Cadena-sintetica-de-prueba');
    hash_dos := grado.crear_hash_contrasena('Cadena-sintetica-de-prueba');
    IF hash_uno = hash_dos THEN RAISE EXCEPTION 'Fallo: falta sal aleatoria.'; END IF;
    IF NOT grado.verificar_hash_contrasena('Cadena-sintetica-de-prueba', hash_uno)
        OR grado.verificar_hash_contrasena('Otra-cadena', hash_uno) THEN
        RAISE EXCEPTION 'Fallo: verificación de contraseña incorrecta.';
    END IF;
    IF grado.verificar_hash_contrasena('cadena', 'MARCADOR_NO_AUTENTICABLE') THEN
        RAISE EXCEPTION 'Fallo: aceptó un hash inválido.';
    END IF;
    esperado := timestamptz '2026-10-19 23:59:00-05';
    IF grado.limite_dias_calendario(timestamptz '2026-10-16 12:00:00-05', 3) <> esperado THEN
        RAISE EXCEPTION 'Fallo: plazo de tres días o cierre del día incorrecto.';
    END IF;
    IF grado.habilitacion_informe(timestamptz '2026-10-16 12:00:00-05')
        <> timestamptz '2027-01-14 00:00:00-05' THEN
        RAISE EXCEPTION 'Fallo: habilitación del informe a los 90 días incorrecta.';
    END IF;
    RAISE NOTICE 'Utilidades verificadas. No se guardaron credenciales de prueba.';
END;
$$;
ROLLBACK;
