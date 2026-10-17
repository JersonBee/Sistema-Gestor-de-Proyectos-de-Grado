<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %>
<%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<%@ include file="/WEB-INF/controladores/comun/post.jsp" %>
<c:catch var="falloSalida"><%@ include file="/WEB-INF/modelo/acciones/salir/salida.jsp" %></c:catch>
<c:set var="sesionCerrada" value="${pageContext.session.invalidate()}" />
<c:redirect url="/ingresar.jsp" />
