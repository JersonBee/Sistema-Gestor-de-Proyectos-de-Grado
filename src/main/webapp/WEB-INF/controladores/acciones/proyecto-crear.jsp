<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",estudiante," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:if test="${empty param.idea or not param.idea.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<c:catch var="falloOperacion"><%@ include file="/WEB-INF/modelo/acciones/proyecto-crear/resultado.jsp" %></c:catch>
<c:set var="avisoFlujo" value="${not empty falloOperacion ? 'No se pudo iniciar el proyecto. Intenta de nuevo.' : resultado.rows[0].mensaje}" scope="session" />
<c:if test="${not empty falloOperacion or not resultado.rows[0].ok}"><c:redirect url="/proyecto-nuevo.jsp"><c:param name="idea" value="${param.idea}" /></c:redirect></c:if><c:redirect url="/pago.jsp"><c:param name="id" value="${resultado.rows[0].recurso_id}" /></c:redirect>
