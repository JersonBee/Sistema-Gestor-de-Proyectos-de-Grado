<%@ page contentType="text/html; charset=UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="estadoRespuesta" value="${pageContext.response.setStatus(503)}" />

<%@ include file="/WEB-INF/vistas/no-disponible.jsp" %>
