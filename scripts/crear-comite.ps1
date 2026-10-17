# Arranque administrativo manual: no autorregistro público ni contraseña predeterminada.
param([string]$Nombre, [string]$Correo)
$ErrorActionPreference = 'Stop'
if (-not $Nombre) { $Nombre = Read-Host 'Nombre de la cuenta del Comité' }
if (-not $Correo) { $Correo = Read-Host 'Correo de acceso' }
if ($Nombre.Trim().Length -lt 2 -or $Correo -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Revisa nombre y correo.' }
$secreto = Read-Host 'Contraseña (mínimo 8 caracteres)' -AsSecureString
$confirmacion = Read-Host 'Repite la contraseña' -AsSecureString
$punteroClave = [IntPtr]::Zero
$punteroConfirmacion = [IntPtr]::Zero
try {
    $punteroClave = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secreto)
    $punteroConfirmacion = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmacion)
    $claveTemporal = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($punteroClave)
    if ($claveTemporal -ne [Runtime.InteropServices.Marshal]::PtrToStringBSTR($punteroConfirmacion)) { throw 'Las contraseñas no coinciden.' }
    if ($claveTemporal.Length -lt 8 -or [Text.Encoding]::UTF8.GetByteCount($claveTemporal) -gt 72) { throw 'La contraseña requiere al menos 8 caracteres y hasta 72 bytes.' }
    $env:GRADO_COMITE_CLAVE = $claveTemporal
    $env:GRADO_COMITE_NOMBRE = $Nombre.Trim()
    $env:GRADO_COMITE_CORREO = $Correo.Trim().ToLowerInvariant()
    $codigo = @'
import java.sql.*;
try {
 Class.forName("org.postgresql.Driver");
 try(var cn=DriverManager.getConnection(System.getenv("DB_JDBC_URL"),System.getenv("DB_USER"),System.getenv("DB_PASSWORD"))) {
  cn.setAutoCommit(false);
  try(var st=cn.createStatement()) { st.execute("SELECT pg_advisory_xact_lock(740017)"); }
  try(var st=cn.createStatement();var rs=st.executeQuery("SELECT EXISTS(SELECT 1 FROM grado.usuario WHERE rol_codigo='comite')")) {
   rs.next(); if(rs.getBoolean(1)) { System.out.println("COMITE_EXISTENTE"); }
   else {
    try(var ps=cn.prepareStatement("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES(?,?,grado.crear_hash_contrasena(?),'comite','activo') RETURNING id")) {
     ps.setString(1,System.getenv("GRADO_COMITE_NOMBRE")); ps.setString(2,System.getenv("GRADO_COMITE_CORREO")); ps.setString(3,System.getenv("GRADO_COMITE_CLAVE"));
     try(var usuario=ps.executeQuery()) { usuario.next(); long id=usuario.getLong(1);
      try(var audit=cn.prepareStatement("INSERT INTO grado.evento_auditoria(actor_id,origen,accion,entidad,entidad_id) VALUES(?,'usuario','alta_inicial_comite','usuario',?)")) { audit.setLong(1,id); audit.setLong(2,id); audit.executeUpdate(); }
     }
    }
    cn.commit(); System.out.println("COMITE_CREADO_OK");
   }
  }
 }
} catch(Exception e) { System.out.println("COMITE_ERROR"); }
/exit
'@
    $rutaCodigo = Join-Path $PSScriptRoot '..\.tools\crear-comite.jsh'
    [IO.File]::WriteAllText($rutaCodigo,$codigo,[Text.UTF8Encoding]::new($false))
    docker compose cp $rutaCodigo aplicacion:/tmp/crear-comite.jsh | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo acceder al contenedor.' }
    $salida = docker compose exec -T -e GRADO_COMITE_NOMBRE -e GRADO_COMITE_CORREO -e GRADO_COMITE_CLAVE aplicacion jshell --class-path /usr/local/tomcat/lib/postgresql-42.7.14.jar --feedback silent /tmp/crear-comite.jsh 2>&1
    if (($salida -join "`n") -match 'COMITE_EXISTENTE') { Write-Output 'Ya hay una cuenta del Comité. No se modificó ninguna cuenta.' }
    elseif ($LASTEXITCODE -eq 0 -and ($salida -join "`n") -match 'COMITE_CREADO_OK') { Write-Output 'Cuenta del Comité creada. Ya puedes iniciar sesión.' }
    else { throw 'No se pudo crear la cuenta. Revisa si el correo ya está registrado y si la base está disponible.' }
} finally {
    if ($punteroClave -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($punteroClave) }
    if ($punteroConfirmacion -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($punteroConfirmacion) }
    $claveTemporal = $null
    Remove-Item Env:GRADO_COMITE_CLAVE, Env:GRADO_COMITE_NOMBRE, Env:GRADO_COMITE_CORREO -ErrorAction SilentlyContinue
    $secreto.Dispose(); $confirmacion.Dispose()
}
