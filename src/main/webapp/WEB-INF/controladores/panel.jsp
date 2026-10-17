<%@ include file="/WEB-INF/controladores/comun/inicio.jsp" %>
<%@ include file="/WEB-INF/controladores/comun/seguridad.jsp" %>
<c:set var="tituloPagina" value="Mi inicio" /><c:set var="menuActual" value="inicio" />
<c:set var="paginaTareas" value="1" /><c:set var="limiteTareas" value="6" />
<c:catch var="falloPanel">
    <%@ include file="/WEB-INF/modelo/tareas/lista.jsp" %>
    <%@ include file="/WEB-INF/modelo/panel/proyectos.jsp" %>
    <%@ include file="/WEB-INF/modelo/panel/avisos.jsp" %>
    <%@ include file="/WEB-INF/modelo/panel/resumen.jsp" %>
</c:catch>
<c:if test="${not empty falloPanel}"><c:redirect url="/no-disponible.jsp" /></c:if>

<%@ include file="/WEB-INF/vistas/panel.jsp" %>
