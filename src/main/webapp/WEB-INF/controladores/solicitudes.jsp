<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/proyecto-acceso.jsp" %>
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" />
<%@ include file="/WEB-INF/modelo/solicitudes/solicitudes.jsp" %>
<c:if test="${proyectoVista.integrante and proyectoVista.estado eq 'activo'}"><%@ include file="/WEB-INF/modelo/solicitudes/aptos.jsp" %></c:if>
<c:set var="tituloPagina" value="Solicitudes" /><c:set var="menuActual" value="inicio" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/solicitudes.jsp" %>
