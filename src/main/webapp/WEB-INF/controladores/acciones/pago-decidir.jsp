<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",comite," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}') or empty param.entrega or not param.entrega.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<c:catch var="falloOperacion"><%@ include file="/WEB-INF/modelo/acciones/pago-decidir/resultado.jsp" %></c:catch>
<c:set var="avisoFlujo" value="${not empty falloOperacion ? 'No se pudo guardar la revisión. Intenta de nuevo.' : resultado.rows[0].mensaje}" scope="session" /><c:redirect url="/pago.jsp"><c:param name="id" value="${param.id}" /></c:redirect>
