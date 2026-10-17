<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.acta or not param.acta.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/acta/actaDatos.jsp" %><c:if test="${empty actaDatos.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="acta" value="${actaDatos.rows[0]}" />
<%@ include file="/WEB-INF/modelo/acta/vinculosActa.jsp" %>
<c:set var="tituloPagina" value="Consulta de acta" /><c:set var="menuActual" value="proyectos" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/acta.jsp" %>
