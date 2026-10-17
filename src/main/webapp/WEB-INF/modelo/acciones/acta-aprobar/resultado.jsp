<sql:query var="resultado" dataSource="${bd}">SELECT * FROM grado.aprobar_acta(?,CAST(? AS bigint))<sql:param value="${sessionScope.tokenAcceso}" /><sql:param value="${param.acta}" /></sql:query>
