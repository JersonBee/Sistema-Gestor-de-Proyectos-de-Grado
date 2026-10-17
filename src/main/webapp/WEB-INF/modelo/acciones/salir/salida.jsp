<sql:query var="salida" dataSource="${bd}">SELECT grado.cerrar_sesion(?)<sql:param value="${sessionScope.tokenAcceso}" /></sql:query>
