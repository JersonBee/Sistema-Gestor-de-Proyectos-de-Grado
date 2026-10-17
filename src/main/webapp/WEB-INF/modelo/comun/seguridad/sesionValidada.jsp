<sql:query var="sesionValidada" dataSource="${bd}">
        SELECT * FROM grado.validar_sesion(?)
        <sql:param value="${sessionScope.tokenAcceso}" />
    </sql:query>
