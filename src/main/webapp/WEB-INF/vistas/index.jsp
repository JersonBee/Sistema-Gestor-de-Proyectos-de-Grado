<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#c7d309">
    <title>Proyectos de grado · UTS</title>
    <link rel="stylesheet" href="<c:url value='/assets/css/base.css' />">
<link rel="stylesheet" href="<c:url value='/assets/css/administracion.css'><c:param name='v' value='20261017-2' /></c:url>">
</head>
<body>
    <a class="saltar" href="#contenido">Ir al contenido</a>
    <header class="cabecera">
        <a class="marca" href="<c:url value='/' />" aria-label="UTS · Inicio">
            <img src="<c:url value='/assets/img/marca-uts.svg' />" alt="Unidades Tecnológicas de Santander" width="360" height="112">
        </a>
        <nav class="nav-portada" aria-label="Acceso al sistema"><a href="<c:url value='/ingresar.jsp' />">Iniciar sesión</a><a class="boton-portada" href="<c:url value='/registro.jsp' />">Crear cuenta →</a></nav>
    </header>
    <main id="contenido" class="portada">
        <p class="antetitulo"><span class="punto" aria-hidden="true"></span> UNIDADES TECNOLÓGICAS DE SANTANDER</p>
        <h1>Sistema de gestión de<br><span>proyectos de grado</span></h1>
        <p class="introduccion">Portal académico para registrar proyectos, gestionar entregas documentales y consultar las decisiones del proceso de grado.</p>
        <div class="acciones-portada"><a class="boton-portada" href="<c:url value='/registro.jsp' />">Registro de estudiantes</a><a href="<c:url value='/registro.jsp'><c:param name='tipo' value='docente' /></c:url>">Registro de docentes</a></div>
        <section class="recorrido" aria-labelledby="titulo-recorrido">
            <div class="encabezado-recorrido">
                <h2 id="titulo-recorrido">Una ruta, seis etapas</h2>
                <p>Avanza con claridad en cada fase de tu proyecto.</p>
            </div>
            <ol class="fases">
                <c:forTokens items="Pago,Propuesta I,Propuesta II,Informe I,Informe II,Final" delims="," var="fase" varStatus="paso">
                    <li><span class="numero"><c:out value="${paso.count}" /></span><span><c:out value="${fase}" /></span></li>
                </c:forTokens>
            </ol>
        </section>
    </main>
    <footer class="pie">Unidades Tecnológicas de Santander <span>Proyectos de grado</span></footer>
</body>
</html>
