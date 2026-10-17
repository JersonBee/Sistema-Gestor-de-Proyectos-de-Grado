<c:if test="${pageContext.request.method ne 'POST' or empty param.csrf or param.csrf ne sessionScope.csrf}">
    <c:redirect url="/denegado.jsp" />
</c:if>
