<%@ page contentType="text/html; charset=UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="sql" uri="jakarta.tags.sql" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<c:set var="cabeceraCache" value="${pageContext.response.setHeader('Cache-Control', 'no-store')}" />
<c:set var="cabeceraTipo" value="${pageContext.response.setHeader('X-Content-Type-Options', 'nosniff')}" />
<c:set var="cabeceraMarco" value="${pageContext.response.setHeader('X-Frame-Options', 'DENY')}" />
<c:catch var="falloInicial">
    <%@ include file="/WEB-INF/modelo/comun/inicio/bd.jsp" %>
    <c:if test="${empty sessionScope.csrf}">
        <%@ include file="/WEB-INF/modelo/comun/inicio/tokenFormulario.jsp" %>
        <c:set var="csrf" value="${tokenFormulario.rows[0].valor}" scope="session" />
    </c:if>
</c:catch>
<c:if test="${not empty falloInicial}"><c:redirect url="/no-disponible.jsp" /></c:if>
