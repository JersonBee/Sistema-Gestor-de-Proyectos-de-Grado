<%@ include file="/WEB-INF/vistas/comun/cabecera.jsp" %>
<main id="contenido" class="pagina-acceso">
    <section class="presentacion-acceso">
        <a href="<c:url value='/' />"><img class="logo-acceso" src="<c:url value='/assets/img/marca-uts.svg' />" width="360" height="112" alt="UTS · Inicio"></a>
        <div><p class="antetitulo">SISTEMA DE GESTIÓN ACADÉMICA</p><h1>Administración de<br>proyectos de grado.</h1><p>Registro, revisión y seguimiento del proceso académico.<br>Información centralizada para estudiantes y docentes.</p></div>
        <p class="firma-acceso">Unidades Tecnológicas de Santander</p>
    </section>
    <section class="formulario-acceso" aria-labelledby="titulo-acceso">
        <p class="sobretitulo">PROYECTOS DE GRADO</p><h2 id="titulo-acceso">Acceso al sistema</h2><p class="descripcion-formulario">Ingresa con tu cuenta para continuar.</p>
        <c:if test="${param.aviso eq 'registro'}"><p class="aviso exito" role="status">Tu cuenta está activa. Ya puedes iniciar sesión.</p></c:if>
        <c:if test="${param.aviso eq 'sesion'}"><p class="aviso" role="status">Tu sesión terminó. Inicia sesión de nuevo.</p></c:if>
        <c:if test="${param.error eq 'credenciales'}"><p class="aviso error" role="alert">No pudimos iniciar sesión. Revisa tus datos o espera unos minutos antes de intentar de nuevo.</p></c:if>
        <c:if test="${param.error eq 'servicio'}"><p class="aviso error" role="alert">No pudimos completar la solicitud. Intenta de nuevo más tarde.</p></c:if>
        <form method="post" action="<c:url value='/acciones/ingresar.jsp' />" class="formulario">
            <input type="hidden" name="csrf" value="<c:out value='${sessionScope.csrf}' />">
            <label for="correo">Correo electrónico</label><input id="correo" name="correo" type="email" maxlength="254" autocomplete="username" required placeholder="tu.correo@ejemplo.com">
            <label for="contrasena">Contraseña</label><input id="contrasena" name="contrasena" type="password" maxlength="72" autocomplete="current-password" required>
            <button class="boton primario ancho" type="submit">Iniciar sesión <span aria-hidden="true">→</span></button>
        </form>
        <p class="alternativa-acceso">¿Aún no tienes cuenta? <a href="<c:url value='/registro.jsp' />">Crear mi cuenta</a></p>
        <p class="dato-secundario">Unidades Tecnológicas de Santander · Gestión académica</p>
    </section>
</main></body></html>
