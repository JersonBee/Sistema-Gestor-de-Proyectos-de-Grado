<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %>
<c:set var="esDocente" value="${param.tipo eq 'docente'}" />
<c:set var="tituloPagina" value="Crear cuenta" />
<c:catch var="falloCatalogos"><%@ include file="/WEB-INF/modelo/registro/modalidades.jsp" %></c:catch>
<c:if test="${not empty falloCatalogos}"><c:redirect url="/no-disponible.jsp" /></c:if>

<c:set var="errorRegistroVista" value="${sessionScope.errorRegistro}" /><c:remove var="errorRegistro" scope="session" />

<%@ include file="/WEB-INF/vistas/registro.jsp" %>
