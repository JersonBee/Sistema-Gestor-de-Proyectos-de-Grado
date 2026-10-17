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
<c:if test="${not empty falloInicial}">
    <%-- Registrar tipos y SQLState, nunca mensajes que puedan contener credenciales. --%>
    <c:set var="causaInicial" value="${falloInicial}" />
    <c:forEach begin="0" end="7" var="nivelInicial">
        <c:if test="${not empty causaInicial}">
            <c:set var="tipoInicial" value="${causaInicial.getClass().getName()}" />
            <c:set var="diagnosticoInicial">BD_INICIO_ERROR nivel=${nivelInicial} tipo=${tipoInicial}</c:set>
            <c:if test="${fn:contains(tipoInicial, 'SQLException') or fn:contains(tipoInicial, 'PSQLException')}">
                <c:set var="diagnosticoInicial">${diagnosticoInicial} SQLState=${causaInicial.getSQLState()}</c:set>
            </c:if>
            <c:set var="registroInicial" value="${pageContext.servletContext.log(diagnosticoInicial)}" />
            <c:set var="causaInicial" value="${causaInicial.cause}" />
        </c:if>
    </c:forEach>
    <c:redirect url="/no-disponible.jsp" />
</c:if>
