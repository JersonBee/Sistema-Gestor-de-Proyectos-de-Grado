<div class="aplicacion">
<aside class="lateral" aria-label="Navegación principal">
    <a class="logo-panel" href="<c:url value='/panel.jsp' />"><img src="<c:url value='/assets/img/marca-uts.svg' />" width="360" height="112" alt="UTS · Inicio"></a>
    <p class="etiqueta-menu">GESTIÓN ACADÉMICA</p>
    <nav>
        <a class="enlace-menu ${menuActual eq 'inicio' ? 'activo' : ''}" href="<c:url value='/panel.jsp' />" aria-current="${menuActual eq 'inicio' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#inicio' />"></use></svg> Mi inicio</a>
        <a class="enlace-menu ${menuActual eq 'cuenta' ? 'activo' : ''}" href="<c:url value='/cuenta.jsp' />" aria-current="${menuActual eq 'cuenta' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#cuenta' />"></use></svg> Mi cuenta</a>
        <a class="enlace-menu ${menuActual eq 'ideas' ? 'activo' : ''}" href="<c:url value='/ideas.jsp' />" aria-current="${menuActual eq 'ideas' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#ideas' />"></use></svg> Banco de ideas</a>
        <a class="enlace-menu ${menuActual eq 'avisos' ? 'activo' : ''}" href="<c:url value='/avisos.jsp' />" aria-current="${menuActual eq 'avisos' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#avisos' />"></use></svg> Mis avisos</a>
        <a class="enlace-menu ${menuActual eq 'proyectos' ? 'activo' : ''}" href="<c:url value='/proyectos.jsp' />" aria-current="${menuActual eq 'proyectos' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#proyectos' />"></use></svg> Proyectos</a>
        <c:if test="${usuarioActual.rol_codigo eq 'comite'}"><a class="enlace-menu ${menuActual eq 'usuarios' ? 'activo' : ''}" href="<c:url value='/usuarios.jsp' />" aria-current="${menuActual eq 'usuarios' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#usuarios' />"></use></svg> Administrar cuentas</a></c:if>
        <a class="enlace-menu ${menuActual eq 'tareas' ? 'activo' : ''}" href="<c:url value='/tareas.jsp' />" aria-current="${menuActual eq 'tareas' ? 'page' : 'false'}"><svg class="icono-menu" aria-hidden="true"><use href="<c:url value='/assets/img/iconos.svg#tareas' />"></use></svg> Mis tareas</a>
    </nav>
    <div class="pie-menu">
        <p class="rol-cuenta"><c:out value="${nombreRol}" /></p>
        <p class="nombre-cuenta"><c:out value="${usuarioActual.nombre}" /></p>
        <form method="post" action="<c:url value='/acciones/salir.jsp' />">
            <input type="hidden" name="csrf" value="<c:out value='${sessionScope.csrf}' />">
            <button class="boton-salir" type="submit">Cerrar sesión <span aria-hidden="true">↗</span></button>
        </form>
    </div>
</aside>
<div class="area-panel">
<header class="barra-panel"><span>Gestión académica <span aria-hidden="true">/</span> <c:out value="${tituloPagina}" /></span><span class="sello-institucional">UTS</span></header>
<main id="contenido" class="contenido-panel">
