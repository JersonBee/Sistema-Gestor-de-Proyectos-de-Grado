<sql:query var="ingreso" dataSource="${bd}">
        SELECT * FROM grado.iniciar_sesion(?, ?)
        <sql:param value="${param.correo}" /><sql:param value="${param.contrasena}" />
    </sql:query>
