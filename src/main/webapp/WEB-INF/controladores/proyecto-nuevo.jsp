<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",estudiante," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.idea or not param.idea.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/proyecto-nuevo/seleccion.jsp" %>
<c:if test="${empty seleccion.rows}"><c:set var="avisoFlujo" value="La idea ya no está disponible." scope="session" /><c:redirect url="/ideas.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/proyecto-nuevo/cuenta.jsp" %>
<%@ include file="/WEB-INF/modelo/proyecto-nuevo/directores.jsp" %>
<c:set var="tituloPagina" value="Iniciar proyecto" /><c:set var="menuActual" value="ideas" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/proyecto-nuevo.jsp" %>
