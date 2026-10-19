<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",director,evaluador,comite," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %><%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}') or empty param.revision or not param.revision.matches('[0-9]{1,18}') or (param.tipo ne 'propuesta' and param.tipo ne 'informe')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/acciones/revision-decidir/contexto.jsp" %>
<c:if test="${empty contextoRevision.rows}"><c:redirect url="/denegado.jsp" /></c:if>
<c:catch var="falloOperacion"><%@ include file="/WEB-INF/modelo/acciones/revision-decidir/resultado.jsp" %></c:catch>
<c:set var="avisoFlujo" value="${not empty falloOperacion ? 'No se pudo registrar la revisión. Intenta de nuevo.' : resultado.rows[0].mensaje}" scope="session" /><c:redirect url="/seguimiento.jsp"><c:param name="id" value="${param.id}" /><c:param name="tipo" value="${param.tipo}" /></c:redirect>
