param([Parameter(Mandatory = $true)][string]$Archivo)
$ErrorActionPreference = 'Stop'
$rutaSql = (Resolve-Path -LiteralPath $Archivo).Path
if ([System.IO.Path]::GetExtension($rutaSql) -ne '.sql') { throw 'Selecciona un archivo SQL.' }
$contenidoSql = [System.IO.File]::ReadAllText($rutaSql)
$sqlCodificado = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($contenidoSql))
$comprobacion = @'
import java.sql.*;
import java.util.Base64;
try { Class.forName("org.postgresql.Driver"); try(var cn = DriverManager.getConnection(System.getenv("DB_JDBC_URL"), System.getenv("DB_USER"), System.getenv("DB_PASSWORD")); var st = cn.createStatement()) { st.execute(new String(Base64.getDecoder().decode("__SQL__"), java.nio.charset.StandardCharsets.UTF_8)); System.out.println("SQL_APLICADO_OK"); } } catch(Exception e) { System.out.println("SQL_ERROR " + e.getClass().getSimpleName()); if(e instanceof SQLException) System.out.println("SQLSTATE=" + ((SQLException)e).getSQLState()); }
/exit
'@
$rutaTemporal = Join-Path $PSScriptRoot '..\.tools\migracion.jsh'
[System.IO.File]::WriteAllText($rutaTemporal, $comprobacion.Replace('__SQL__', $sqlCodificado), [System.Text.UTF8Encoding]::new($false))
docker compose cp $rutaTemporal aplicacion:/tmp/migracion.jsh | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo copiar la migración al contenedor.' }
$salida = docker compose exec -T aplicacion jshell --class-path /usr/local/tomcat/lib/postgresql-42.7.14.jar --feedback silent /tmp/migracion.jsh 2>&1
if ($LASTEXITCODE -ne 0 -or ($salida -join "`n") -notmatch 'SQL_APLICADO_OK') {
    throw 'La operación SQL no terminó correctamente. Revisa el archivo y los permisos de conexión; no se mostraron credenciales.'
}
Write-Output "SQL aplicado: $([System.IO.Path]::GetFileName($rutaSql))."
