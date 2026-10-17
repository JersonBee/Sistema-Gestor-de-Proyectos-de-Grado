<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="tituloPagina" value="Banco de ideas" /><c:set var="menuActual" value="ideas" />
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" />
<%@ include file="/WEB-INF/modelo/ideas/ideas.jsp" %>

<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/ideas.jsp" %>
