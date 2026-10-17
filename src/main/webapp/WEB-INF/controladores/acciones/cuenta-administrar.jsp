<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",comite," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:if test="${empty param.usuario or not param.usuario.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<c:catch var="falloOperacion"><%@ include file="/WEB-INF/modelo/acciones/cuenta-administrar/resultado.jsp" %></c:catch>
<c:set var="avisoFlujo" value="${not empty falloOperacion ? 'No se pudo completar la operación. Revisa los datos e intenta de nuevo.' : resultado.rows[0].mensaje}" scope="session" />
<c:redirect url="/usuario.jsp"><c:param name="usuario" value="${param.usuario}" /></c:redirect>
