<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",comite," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.usuario or not param.usuario.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/usuario/consultaCuenta.jsp" %><c:if test="${empty consultaCuenta.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="cuenta" value="${consultaCuenta.rows[0]}" />
<%@ include file="/WEB-INF/modelo/usuario/roles.jsp" %><%@ include file="/WEB-INF/modelo/usuario/modalidades.jsp" %>
<%@ include file="/WEB-INF/modelo/usuario/movimientos.jsp" %>
<c:set var="tituloPagina" value="Administrar cuenta" /><c:set var="menuActual" value="usuarios" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/usuario.jsp" %>
