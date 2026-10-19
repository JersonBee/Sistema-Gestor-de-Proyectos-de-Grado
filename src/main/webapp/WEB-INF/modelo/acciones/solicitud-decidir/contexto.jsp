<sql:query var="contextoSolicitud" dataSource="${bd}">
 SELECT id FROM grado.solicitud WHERE id=CAST(? AS bigint) AND proyecto_id=CAST(? AS bigint)
 <sql:param value="${param.solicitud}" /><sql:param value="${param.id}" />
</sql:query>
