<sql:query var="resultado" dataSource="${bd}">SELECT * FROM grado.leer_mensajes(?,CAST(? AS bigint))<sql:param value="${sessionScope.tokenAcceso}" /><sql:param value="${param.id}" /></sql:query>
