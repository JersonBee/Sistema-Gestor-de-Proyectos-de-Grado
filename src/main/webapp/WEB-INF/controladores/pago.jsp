<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/pago/pagoDatos.jsp" %>
<c:if test="${empty pagoDatos.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="pago" value="${pagoDatos.rows[0]}" />
<%@ include file="/WEB-INF/modelo/pago/entregas.jsp" %>
<%@ include file="/WEB-INF/modelo/pago/adjuntos.jsp" %>
<%@ include file="/WEB-INF/modelo/pago/participantesPago.jsp" %>
<c:if test="${usuarioActual.rol_codigo eq 'comite' and not empty pago.aprobado_en and empty pago.finalizada_en}"><%@ include file="/WEB-INF/modelo/pago/aptos.jsp" %></c:if>
<c:set var="ultimaEntrega" value="${entregas.rows[0]}" /><c:set var="tituloPagina" value="Revisión del pago" /><c:set var="menuActual" value="inicio" />
<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/pago.jsp" %>
