<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %>
<%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:if test="${fn:length(param.contrasena.getBytes('UTF-8')) gt 72}">
    <c:set var="errorRegistro" value="La contraseña supera 72 bytes UTF-8. Las tildes y emojis pueden ocupar varios bytes; elige una contraseña más corta." scope="session" />
    <c:redirect url="/registro.jsp"><c:param name="tipo" value="${param.tipo eq 'docente' ? 'docente' : 'estudiante'}" /></c:redirect>
</c:if>
<c:if test="${empty param.contrasena or param.contrasena ne param.confirmacion}">
    <c:set var="errorRegistro" value="Las contraseñas no coinciden." scope="session" />
    <c:redirect url="/registro.jsp"><c:param name="tipo" value="${param.tipo eq 'docente' ? 'docente' : 'estudiante'}" /></c:redirect>
</c:if>
<c:catch var="falloRegistro">
    <%@ include file="/WEB-INF/modelo/acciones/registrar/registro.jsp" %>
</c:catch>
<c:if test="${not empty falloRegistro}"><c:set var="errorRegistro" value="No pudimos completar el registro. Intenta de nuevo más tarde." scope="session" /><c:redirect url="/registro.jsp"><c:param name="tipo" value="${param.tipo}" /></c:redirect></c:if>
<c:if test="${not registro.rows[0].ok}"><c:set var="errorRegistro" value="${registro.rows[0].mensaje}" scope="session" /><c:redirect url="/registro.jsp"><c:param name="tipo" value="${param.tipo}" /></c:redirect></c:if>
<c:redirect url="/ingresar.jsp"><c:param name="aviso" value="registro" /></c:redirect>
