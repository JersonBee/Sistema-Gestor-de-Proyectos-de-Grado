<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/comun/proyecto-acceso/proyectoConsulta.jsp" %>
<c:if test="${empty proyectoConsulta.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="proyectoVista" value="${proyectoConsulta.rows[0]}" />
