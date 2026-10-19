<c:if test="${pageContext.request.method ne 'POST' or empty param.csrf or param.csrf ne sessionScope.csrf}">
    <c:choose>
        <c:when test="${pageContext.request.method ne 'POST'}"><c:set var="motivoCsrf" value="metodo" /></c:when>
        <c:when test="${empty param.csrf}"><c:set var="motivoCsrf" value="token_ausente" /></c:when>
        <c:when test="${empty sessionScope.csrf}"><c:set var="motivoCsrf" value="sesion_ausente" /></c:when>
        <c:otherwise><c:set var="motivoCsrf" value="token_distinto" /></c:otherwise>
    </c:choose>
    <c:set var="diagnosticoCsrf">CSRF_RECHAZADO motivo=${motivoCsrf}</c:set>
    <c:set var="registroCsrf" value="${pageContext.servletContext.log(diagnosticoCsrf)}" />
    <c:redirect url="/denegado.jsp" />
</c:if>
