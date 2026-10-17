<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" />
<c:catch var="falloBusqueda"><%@ include file="/WEB-INF/modelo/proyectos/lista.jsp" %></c:catch>
<%@ include file="/WEB-INF/modelo/proyectos/modalidades.jsp" %><%@ include file="/WEB-INF/modelo/proyectos/fases.jsp" %>
<c:set var="tituloPagina" value="Proyectos" /><c:set var="menuActual" value="proyectos" />
<%@ include file="/WEB-INF/vistas/proyectos.jsp" %>
