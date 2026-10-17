<sql:query var="resumen" dataSource="${bd}">
        SELECT count(*) FILTER (WHERE p.estado = 'activo') AS activos,
            count(*) FILTER (WHERE p.estado = 'finalizado') AS finalizados,
            count(*) FILTER (WHERE p.estado = 'desactivado') AS pausados
        FROM grado.proyecto p WHERE grado.puede_consultar_proyecto(CAST(? AS bigint), p.id)
        <sql:param value="${usuarioActual.id}" />
    </sql:query>
