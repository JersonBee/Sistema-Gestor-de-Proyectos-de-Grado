<sql:query var="registro" dataSource="${bd}">
        SELECT * FROM grado.registrar_cuenta(?, ?, ?, ?, ?, ?, jsonb_build_object(
            'areas', CAST(? AS text), 'lineas', CAST(? AS text), 'cursos', CAST(? AS text),
            'titulos', CAST(? AS text), 'temas', CAST(? AS text), 'modalidades', CAST(? AS text)))
        <sql:param value="${param.nombre}" /><sql:param value="${param.correo}" /><sql:param value="${param.contrasena}" />
        <sql:param value="${param.documento}" /><sql:param value="${param.telefono}" /><sql:param value="${param.rol}" />
        <sql:param value="${param.areas}" /><sql:param value="${param.lineas}" /><sql:param value="${param.cursos}" />
        <sql:param value="${param.titulos}" /><sql:param value="${param.temas}" /><sql:param value="${fn:join(paramValues.modalidad, ',')}" />
    </sql:query>
