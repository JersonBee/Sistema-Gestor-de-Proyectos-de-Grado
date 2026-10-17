<sql:query var="proyectos" dataSource="${bd}">
        SELECT p.id, p.titulo, p.estado, m.nombre AS modalidad,
            coalesce((SELECT f.nombre FROM grado.proyecto_fase pf JOIN grado.fase f ON f.codigo = pf.fase_codigo
                WHERE pf.proyecto_id = p.id AND pf.iniciada_en IS NOT NULL AND pf.finalizada_en IS NULL LIMIT 1), CASE WHEN p.estado IN ('cancelado','finalizado') THEN 'Proceso cerrado' ELSE 'Por iniciar' END) AS fase
        FROM grado.proyecto p JOIN grado.modalidad m ON m.id = p.modalidad_id
        WHERE grado.puede_consultar_proyecto(CAST(? AS bigint), p.id) ORDER BY p.creado_en DESC LIMIT 20
        <sql:param value="${usuarioActual.id}" />
    </sql:query>
