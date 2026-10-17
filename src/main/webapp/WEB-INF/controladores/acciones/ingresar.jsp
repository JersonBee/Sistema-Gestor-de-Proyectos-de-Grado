<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %>
<%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:catch var="falloIngreso">
    <%@ include file="/WEB-INF/modelo/acciones/ingresar/ingreso.jsp" %>
</c:catch>
<c:if test="${not empty falloIngreso}"><c:redirect url="/ingresar.jsp"><c:param name="error" value="servicio" /></c:redirect></c:if>
<c:if test="${ingreso.rowCount ne 1}"><c:redirect url="/ingresar.jsp"><c:param name="error" value="credenciales" /></c:redirect></c:if>
<c:set var="identificadorRotado" value="${pageContext.request.changeSessionId()}" />
<c:set var="tokenAcceso" value="${ingreso.rows[0].token}" scope="session" />
<c:remove var="csrf" scope="session" />
<c:redirect url="/panel.jsp" />
