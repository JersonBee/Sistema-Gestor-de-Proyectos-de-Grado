<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",comite," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="pagina" value="${not empty param.pagina and param.pagina.matches('[1-9][0-9]{0,4}') ? param.pagina : 1}" />
<%@ include file="/WEB-INF/modelo/usuarios/cuentas.jsp" %>
<c:set var="tituloPagina" value="Administración de cuentas" /><c:set var="menuActual" value="usuarios" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/usuarios.jsp" %>
