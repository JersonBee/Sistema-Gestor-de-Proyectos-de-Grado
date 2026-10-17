<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="tituloPagina" value="Mi cuenta" /><c:set var="menuActual" value="cuenta" />
<%@ include file="/WEB-INF/modelo/cuenta/cuenta.jsp" %>
<c:if test="${usuarioActual.rol_codigo eq 'director' or usuarioActual.rol_codigo eq 'evaluador'}">
    <%@ include file="/WEB-INF/modelo/cuenta/perfil.jsp" %>
</c:if>

<%@ include file="/WEB-INF/vistas/cuenta.jsp" %>
