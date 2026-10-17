<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="Content-Security-Policy" content="default-src 'self'; img-src 'self'; style-src 'self'; script-src 'none'; form-action 'self'; base-uri 'self'; frame-src ${permitirVistaDocumento ? 'https: http:' : '\'none\''}">
    <title><c:out value="${tituloPagina}" /> · Proyectos de grado UTS</title>
    <link rel="stylesheet" href="<c:url value='/assets/css/base.css' />">
    <link rel="stylesheet" href="<c:url value='/assets/css/sistema.css'><c:param name='v' value='20261017-1' /></c:url>">
<link rel="stylesheet" href="<c:url value='/assets/css/administracion.css'><c:param name='v' value='20261017-4' /></c:url>">
<link rel="stylesheet" href="<c:url value='/assets/css/inicio-identidad.css'><c:param name='v' value='20261017-1' /></c:url>">
</head>
<body class="${menuActual eq 'inicio' and tituloPagina eq 'Mi inicio' ? 'pagina-inicio' : ''}">
<a class="saltar" href="#contenido">Ir al contenido</a>
