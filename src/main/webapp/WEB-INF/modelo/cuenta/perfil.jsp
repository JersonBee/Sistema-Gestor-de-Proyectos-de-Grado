<sql:query var="perfil" dataSource="${bd}">
        SELECT p.cursos, p.titulos_academicos, p.temas_preferencia,
            (SELECT string_agg(a.nombre, ', ' ORDER BY a.nombre) FROM grado.docente_area da JOIN grado.area_experiencia a ON a.id = da.area_id WHERE da.docente_id = p.usuario_id) AS areas,
            (SELECT string_agg(l.nombre, ', ' ORDER BY l.nombre) FROM grado.docente_linea dl JOIN grado.linea_investigacion l ON l.id = dl.linea_id WHERE dl.docente_id = p.usuario_id) AS lineas,
            (SELECT string_agg(m.nombre, ', ' ORDER BY m.nombre) FROM grado.docente_modalidad dm JOIN grado.modalidad m ON m.id = dm.modalidad_id WHERE dm.docente_id = p.usuario_id) AS modalidades
        FROM grado.perfil_docente p WHERE p.usuario_id = CAST(? AS bigint)<sql:param value="${usuarioActual.id}" />
    </sql:query>
