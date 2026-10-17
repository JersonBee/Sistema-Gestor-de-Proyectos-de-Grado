<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" /><c:set var="tituloPagina" value="Mis avisos" /><c:set var="menuActual" value="avisos" />
<%@ include file="/WEB-INF/modelo/avisos/notificaciones.jsp" %>

<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/avisos.jsp" %>
