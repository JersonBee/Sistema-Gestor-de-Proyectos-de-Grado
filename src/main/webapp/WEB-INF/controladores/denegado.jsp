<%@ page contentType="text/html; charset=UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="estadoRespuesta" value="${pageContext.response.setStatus(403)}" />

<%@ include file="/WEB-INF/vistas/denegado.jsp" %>
