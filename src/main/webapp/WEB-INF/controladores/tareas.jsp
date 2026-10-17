<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="paginaTareas" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" /><c:set var="limiteTareas" value="21" />
<%@ include file="/WEB-INF/modelo/tareas/lista.jsp" %>
<c:set var="tituloPagina" value="Mis tareas" /><c:set var="menuActual" value="tareas" />
<%@ include file="/WEB-INF/vistas/tareas.jsp" %>
