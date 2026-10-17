param([string]$BaseUrl = 'http://localhost:8080')
$ErrorActionPreference = 'Stop'
$raizProyecto = Split-Path -Parent $PSScriptRoot
$archivoWar = Join-Path $raizProyecto 'target/proyectos-grado.war'
if (-not (Test-Path -LiteralPath $archivoWar)) { throw 'Primero compila el WAR con mvnw.cmd package.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$war = [System.IO.Compression.ZipFile]::OpenRead($archivoWar)
try {
    $entradas = @($war.Entries | ForEach-Object { $_.FullName })
    if ($entradas -match '^WEB-INF/lib/jakarta\.(servlet|el)-api-') {
        throw 'El WAR duplica las API de Servlet/EL que debe proporcionar Tomcat.'
    }
    foreach ($esperada in @('WEB-INF/lib/jakarta.servlet.jsp.jstl-api-3.0.2.jar',
            'WEB-INF/lib/jakarta.servlet.jsp.jstl-3.0.1.jar',
            'WEB-INF/lib/postgresql-42.7.14.jar', 'WEB-INF/web.xml', 'index.jsp', 'salud.jsp')) {
        if ($entradas -notcontains $esperada) { throw "Falta en el WAR: $esperada" }
    }
} finally { $war.Dispose() }
$vistas = Join-Path $raizProyecto 'src/main/webapp'
$carpetaModelo = Join-Path $vistas 'WEB-INF/modelo'
$carpetaVistas = Join-Path $vistas 'WEB-INF/vistas'
$carpetaControladores = Join-Path $vistas 'WEB-INF/controladores'
foreach ($capa in @($carpetaModelo, $carpetaVistas, $carpetaControladores)) {
    if (-not (Test-Path -LiteralPath $capa -PathType Container)) { throw 'Falta una capa de la estructura MVC.' }
}
foreach ($archivo in Get-ChildItem -LiteralPath $vistas -Recurse -File) {
    if ($archivo.Extension -in @('.java', '.jspf', '.js')) { throw "Archivo no permitido en estas vistas: $($archivo.Name)" }
    if ($archivo.Extension -eq '.jsp') {
        $contenido = Get-Content -LiteralPath $archivo.FullName -Raw
        if ($contenido -match '<sql:' -and -not $archivo.FullName.StartsWith($carpetaModelo + [IO.Path]::DirectorySeparatorChar)) { throw "SQL fuera del modelo: $($archivo.Name)" }
        if ($archivo.FullName.StartsWith($carpetaVistas + [IO.Path]::DirectorySeparatorChar) -and $contenido -match '<c:redirect\b|pageContext\.(request|response)|/WEB-INF/(modelo|controladores)/') { throw "La vista contiene responsabilidades de otra capa: $($archivo.Name)" }
        if ($contenido -match '<%(?!@)|<jsp:(scriptlet|expression|declaration)\b|<script\b|\son\w+\s*=') {
            throw "Se encontró código no permitido en la vista: $($archivo.Name)"
        }
    }
}
$salud = Invoke-WebRequest -UseBasicParsing -Uri "$($BaseUrl.TrimEnd('/'))/salud.jsp"
if ($salud.StatusCode -ne 200 -or $salud.Content.Trim() -ne 'OK') { throw 'La prueba de JSTL no respondió OK.' }
$portada = Invoke-WebRequest -UseBasicParsing -Uri "$($BaseUrl.TrimEnd('/'))/"
if ($portada.StatusCode -ne 200 -or $portada.Content -notmatch 'Acceso al sistema' -or
    $portada.Content -match '<c:|\$\{') { throw 'La entrada no mostró el formulario de acceso.' }
Write-Output 'OK: WAR con dependencias, vistas sin código prohibido, JSTL y entrada al login responden HTTP 200.'
