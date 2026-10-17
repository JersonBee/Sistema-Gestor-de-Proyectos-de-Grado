<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/idea/ideaDatos.jsp" %>
<c:if test="${empty ideaDatos.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="idea" value="${ideaDatos.rows[0]}" />
<%@ include file="/WEB-INF/modelo/idea/aptos.jsp" %>
<%@ include file="/WEB-INF/modelo/idea/decisiones.jsp" %>
<c:set var="tituloPagina" value="Detalle de la idea" /><c:set var="menuActual" value="ideas" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/idea.jsp" %>
