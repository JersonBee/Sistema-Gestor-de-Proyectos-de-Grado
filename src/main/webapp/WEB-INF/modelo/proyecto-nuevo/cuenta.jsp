<sql:query var="cuenta" dataSource="${bd}">SELECT nombre,correo,numero_documento,telefono FROM grado.usuario WHERE id=CAST(? AS bigint)<sql:param value="${usuarioActual.id}" /></sql:query>
