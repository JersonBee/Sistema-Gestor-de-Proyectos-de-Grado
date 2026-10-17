<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %><c:set var="rolesPermitidos" value=",estudiante,director," /><%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="tituloPagina" value="Proponer idea" /><c:set var="menuActual" value="ideas" />
<%@ include file="/WEB-INF/modelo/idea-nueva/modalidades.jsp" %>
<%@ include file="/WEB-INF/modelo/idea-nueva/areas.jsp" %>
<%@ include file="/WEB-INF/modelo/idea-nueva/lineas.jsp" %>

<%@ include file="/WEB-INF/controladores/comun/preparar-aviso.jsp" %>

<%@ include file="/WEB-INF/vistas/idea-nueva.jsp" %>
