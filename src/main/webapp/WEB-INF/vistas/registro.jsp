<%@ include file="/WEB-INF/vistas/comun/cabecera.jsp" %>
<main id="contenido" class="registro-contenedor">
    <header class="registro-cabecera"><a href="<c:url value='/' />"><img src="<c:url value='/assets/img/marca-uts.svg' />" width="360" height="112" alt="UTS · Inicio"></a><a href="<c:url value='/ingresar.jsp' />">Ya tengo cuenta →</a></header>
    <section class="tarjeta-registro">
        <p class="sobretitulo">EMPIEZA TU RECORRIDO</p><h1>Tu cuenta, tu próximo paso.</h1>
        <p class="descripcion-formulario">Elige cómo participarás en el seguimiento de los proyectos.</p>
        <nav class="selector-registro" aria-label="Tipo de registro">
            <a class="${not esDocente ? 'seleccionado' : ''}" href="<c:url value='/registro.jsp' />">Soy estudiante</a>
            <a class="${esDocente ? 'seleccionado' : ''}" href="<c:url value='/registro.jsp'><c:param name='tipo' value='docente' /></c:url>">Soy docente</a>
        </nav>
        <c:if test="${not empty errorRegistroVista}"><p class="aviso error" role="alert"><c:out value="${errorRegistroVista}" /></p></c:if>
        <form method="post" action="<c:url value='/acciones/registrar.jsp' />" class="formulario">
            <input type="hidden" name="csrf" value="<c:out value='${sessionScope.csrf}' />"><input type="hidden" name="tipo" value="${esDocente ? 'docente' : 'estudiante'}">
            <div class="rejilla-formulario">
                <div class="campo completo"><label for="nombre">Nombres y apellidos</label><input id="nombre" name="nombre" maxlength="120" minlength="2" autocomplete="name" required></div>
                <div class="campo"><label for="documento">Documento de identidad <span>(opcional)</span></label><input id="documento" name="documento" maxlength="40"></div>
                <div class="campo"><label for="telefono">Teléfono <span>(opcional)</span></label><input id="telefono" name="telefono" type="tel" maxlength="40" autocomplete="tel"></div>
                <div class="campo completo"><label for="correo">Correo electrónico</label><input id="correo" name="correo" type="email" maxlength="254" autocomplete="email" required></div>
                <div class="campo"><label for="contrasena">Contraseña</label><input id="contrasena" name="contrasena" type="password" minlength="8" maxlength="72" autocomplete="new-password" aria-describedby="ayuda-contrasena" required></div>
                <div class="campo"><label for="confirmacion">Confirmar contraseña</label><input id="confirmacion" name="confirmacion" type="password" minlength="8" maxlength="72" autocomplete="new-password" required></div>
                <p class="ayuda completo" id="ayuda-contrasena">Usa al menos 8 caracteres. La contraseña puede ocupar hasta 72 bytes.</p>
                <c:choose><c:when test="${esDocente}">
                    <div class="campo completo"><label for="rol">Rol docente</label><select id="rol" name="rol" required><option value="director">Director</option><option value="evaluador">Evaluador</option></select></div>
                    <h2 class="titulo-seccion-form completo">Tu perfil docente</h2>
                    <div class="campo completo"><label for="areas">Áreas de experiencia</label><input id="areas" name="areas" maxlength="1000" placeholder="Separa las áreas con comas" required></div>
                    <div class="campo completo"><label for="lineas">Líneas de investigación</label><input id="lineas" name="lineas" maxlength="1000" placeholder="Separa las líneas con comas" required></div>
                    <div class="campo completo"><label for="cursos">Cursos</label><textarea id="cursos" name="cursos" rows="2" maxlength="4000" required></textarea></div>
                    <div class="campo completo"><label for="titulos">Títulos académicos</label><textarea id="titulos" name="titulos" rows="2" maxlength="4000" required></textarea></div>
                    <div class="campo completo"><label for="temas">Temas de preferencia</label><textarea id="temas" name="temas" rows="2" maxlength="4000" required></textarea></div>
                    <fieldset class="completo"><legend>Modalidades en las que trabajas</legend><div class="opciones-modalidad"><c:forEach items="${modalidades.rows}" var="modalidad"><label class="opcion-check"><input type="checkbox" name="modalidad" value="<c:out value='${modalidad.codigo}' />"><c:out value="${modalidad.nombre}" /></label></c:forEach></div><p class="ayuda">Selecciona al menos una modalidad.</p></fieldset>
                </c:when><c:otherwise><input type="hidden" name="rol" value="estudiante"></c:otherwise></c:choose>
            </div>
            <button class="boton primario ancho" type="submit">Crear mi cuenta <span aria-hidden="true">→</span></button>
        </form>
        <p class="alternativa-acceso">¿Ya tienes cuenta? <a href="<c:url value='/ingresar.jsp' />">Iniciar sesión</a></p>
    </section>
</main></body></html>
