<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:if test="${empty param.version or not param.version.matches('[0-9]{1,18}')}"><c:redirect url="/denegado.jsp" /></c:if>
<%@ include file="/WEB-INF/modelo/documento/archivo.jsp" %>
<c:if test="${empty archivo.rows}"><c:redirect url="/denegado.jsp" /></c:if><c:set var="tituloPagina" value="Previsualización" /><c:set var="permitirVistaDocumento" value="true" />
<%@ include file="/WEB-INF/vistas/documento.jsp" %>
