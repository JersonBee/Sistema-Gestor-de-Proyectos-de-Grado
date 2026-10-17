<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/proyecto-acceso.jsp" %>
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" />
<%@ include file="/WEB-INF/modelo/historial/eventos.jsp" %>
<c:set var="tituloPagina" value="Historial del proyecto" /><c:set var="menuActual" value="inicio" />
<%@ include file="/WEB-INF/vistas/historial.jsp" %>
