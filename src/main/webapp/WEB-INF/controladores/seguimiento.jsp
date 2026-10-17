<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}') or (param.tipo ne 'propuesta' and param.tipo ne 'informe')}"><c:redirect url="/denegado.jsp" /></c:if>
<c:set var="origen" value="${param.tipo eq 'propuesta' ? 'propuesta_1' : 'informe_1'}" />
<%@ include file="/WEB-INF/modelo/seguimiento/info.jsp" %>
<c:if test="${empty info.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="proyecto" value="${info.rows[0]}" />
<%@ include file="/WEB-INF/modelo/seguimiento/entregas.jsp" %>
<%@ include file="/WEB-INF/modelo/seguimiento/revisiones.jsp" %>
<%@ include file="/WEB-INF/modelo/seguimiento/pendientes.jsp" %>
<%@ include file="/WEB-INF/modelo/seguimiento/adjuntos.jsp" %>
<%@ include file="/WEB-INF/modelo/seguimiento/correcciones.jsp" %>
<c:set var="pendiente" value="${pendientes.rows[0]}" /><c:set var="tituloPagina" value="${param.tipo eq 'propuesta' ? 'Propuesta' : 'Informe'}" /><c:set var="menuActual" value="inicio" />

<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/seguimiento.jsp" %>
