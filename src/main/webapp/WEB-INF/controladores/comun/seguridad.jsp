<c:if test="${empty sessionScope.tokenAcceso}"><c:redirect url="/ingresar.jsp" /></c:if>
<c:catch var="falloSesion">
    <%@ include file="/WEB-INF/modelo/comun/seguridad/sesionValidada.jsp" %>
</c:catch>
<c:if test="${not empty falloSesion}"><c:redirect url="/no-disponible.jsp" /></c:if>
<c:if test="${sesionValidada.rowCount ne 1}">
    <c:remove var="tokenAcceso" scope="session" />
    <c:redirect url="/ingresar.jsp"><c:param name="aviso" value="sesion" /></c:redirect>
</c:if>
<c:set var="usuarioActual" value="${sesionValidada.rows[0]}" scope="request" />
<c:set var="rolDelimitado" value=",${usuarioActual.rol_codigo}," />
<c:if test="${not empty rolesPermitidos and not fn:contains(rolesPermitidos, rolDelimitado)}">
    <c:redirect url="/denegado.jsp" />
</c:if>
<c:choose>
    <c:when test="${usuarioActual.rol_codigo eq 'estudiante'}"><c:set var="nombreRol" value="Estudiante" /></c:when>
    <c:when test="${usuarioActual.rol_codigo eq 'director'}"><c:set var="nombreRol" value="Director" /></c:when>
    <c:when test="${usuarioActual.rol_codigo eq 'evaluador'}"><c:set var="nombreRol" value="Evaluador" /></c:when>
    <c:when test="${usuarioActual.rol_codigo eq 'comite'}"><c:set var="nombreRol" value="Comité / Coordinador" /></c:when>
    <c:otherwise><c:set var="nombreRol" value="Secretaría" /></c:otherwise>
</c:choose>
