<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="tituloPagina" value="Detalle del proyecto" />
<c:if test="${empty param.id or not param.id.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/proyecto/detalle.jsp" %>
<c:if test="${empty detalle.rows}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/proyecto/integrantes.jsp" %>
<%@ include file="/WEB-INF/modelo/proyecto/docentes.jsp" %>
<%@ include file="/WEB-INF/modelo/proyecto/fasesProyecto.jsp" %>
<%@ include file="/WEB-INF/modelo/proyecto/documentosFases.jsp" %>
<%@ include file="/WEB-INF/modelo/proyecto/revisionesFases.jsp" %>
<%@ include file="/WEB-INF/modelo/final/datosFinales.jsp" %>

<%@ include file="/WEB-INF/modelo/proyecto/pausas.jsp" %>

<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/proyecto.jsp" %>
