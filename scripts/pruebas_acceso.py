"""Pruebas HTTP reales en Docker aislado. No utiliza .env ni accede a Supabase."""
from pathlib import Path
import html.parser
import http.cookiejar
import json
import secrets
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

RAIZ = Path(__file__).resolve().parent.parent
DOCKER = ['docker', 'compose', '-p', 'grado-pruebas', '-f', 'compose.pruebas.yaml']
BASE = 'http://127.0.0.1:8082'

def ejecutar(args, entrada=None):
    resultado = subprocess.run(args, input=entrada, text=True, encoding='utf-8',
        errors='replace', cwd=RAIZ, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if resultado.returncode:
        raise RuntimeError('Falló el comando de pruebas: ' + ' '.join(args[:8]) + '\n' + resultado.stderr[-3000:])
    return resultado.stdout

def sql(contenido):
    return ejecutar(DOCKER + ['exec', '-T', 'bd_pruebas', 'psql', '-v', 'ON_ERROR_STOP=1',
        '-At', '-U', 'pruebas', '-d', 'grado_pruebas'], contenido)

class Formulario(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.csrf = None
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'input' and a.get('name') == 'csrf': self.csrf = a.get('value')

class Cliente:
    def __init__(self):
        self.cookies = http.cookiejar.CookieJar()
        self.http = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.cookies))
    def pedir(self, ruta, datos=None):
        entrada = urllib.parse.urlencode(datos, doseq=True).encode() if datos is not None else None
        try: respuesta = self.http.open(BASE + ruta, data=entrada, timeout=30)
        except urllib.error.HTTPError as error: respuesta = error
        return respuesta.status, respuesta.geturl(), respuesta.read().decode('utf-8'), respuesta.headers
    def token(self, ruta='/ingresar.jsp'):
        estado, _, cuerpo, _ = self.pedir(ruta)
        assert estado == 200, ('Formulario no disponible', estado, cuerpo[:150])
        f = Formulario(); f.feed(cuerpo); assert f.csrf, 'Falta token CSRF'; return f.csrf
    def id_sesion(self):
        return next((c.value for c in self.cookies if c.name == 'JSESSIONID'), '')

def comprobar():
    from verificar_mvc import verificar
    verificar()
    clave_bd = secrets.token_hex(24)
    clave_cuenta = secrets.token_hex(10)
    herramientas = RAIZ/'.tools'; herramientas.mkdir(exist_ok=True)
    (herramientas/'pruebas.env').write_text(
        'POSTGRES_DB=grado_pruebas\nPOSTGRES_USER=pruebas\nPOSTGRES_PASSWORD='+clave_bd+
        '\nDB_JDBC_URL=jdbc:postgresql://bd_pruebas:5432/grado_pruebas?currentSchema=grado\nDB_USER=pruebas\nDB_PASSWORD='+clave_bd+'\n', encoding='utf-8')
    ejecutar(DOCKER + ['up', '--build', '-d'])
    # Compose conserva el volumen anónimo de PostgreSQL entre ejecuciones.
    # Sincronizar solo la clave del usuario de esta base local de pruebas.
    sql("ALTER ROLE pruebas WITH PASSWORD '"+clave_bd+"';")
    # Recreación del esquema únicamente en esta base de prueba nombrada y aislada.
    sql('DROP SCHEMA IF EXISTS grado CASCADE;')
    for nombre in ['001_estructura.sql', '002_catalogos.sql', '004_utilidades.sql', '006_acceso.sql', '007_ideas_pago.sql', '008_revisiones_plazos.sql', '010_final_solicitudes.sql', '011_administracion_comunicacion.sql', '012_validacion_perfil_docente.sql', '013_sesiones_http.sql', '014_enlaces_adicionales_multilinea.sql', '015_validacion_espacios_perfil.sql']:
        sql((RAIZ/'database'/nombre).read_text(encoding='utf-8'))
    sql((RAIZ/'database/003_verificacion.sql').read_text(encoding='utf-8'))
    sql((RAIZ/'database/005_verificacion_utilidades.sql').read_text(encoding='utf-8'))
    c = Cliente()
    for _ in range(30):
        try:
            if c.pedir('/salud.jsp')[0] == 200: break
        except OSError: pass
        time.sleep(1)
    estado, ruta, _, _ = c.pedir('/panel.jsp')
    assert estado == 200 and '/ingresar.jsp' in ruta, 'Permitió acceso sin sesión'
    csrf = c.token('/registro.jsp')
    assert c.pedir('/acciones/registrar.jsp', {'csrf':'incorrecto'})[0] == 403, 'No bloqueó CSRF'
    estudiante = {'csrf':csrf,'tipo':'estudiante','rol':'estudiante','nombre':'Estudiante de prueba',
        'correo':'estudiante@prueba.invalid','contrasena':clave_cuenta,'confirmacion':clave_cuenta}
    estado, ruta, cuerpo, _ = c.pedir('/acciones/registrar.jsp', estudiante)
    assert estado == 200 and 'aviso=registro' in ruta, ('Registro fallido', ruta, cuerpo[:100])
    assert sql("SELECT estado FROM grado.usuario WHERE correo='estudiante@prueba.invalid';").strip() == 'activo'
    assert sql("SELECT contrasena_hash LIKE '$2%' FROM grado.usuario WHERE correo='estudiante@prueba.invalid';").strip() == 't'
    csrf = c.token()
    estado, ruta, cuerpo, _ = c.pedir('/acciones/ingresar.jsp', {'csrf':csrf,'correo':"' OR 1=1 --",'contrasena':clave_cuenta})
    assert 'error=credenciales' in ruta, 'El inicio de sesión aceptó inyección SQL'
    csrf = c.token(); id_previo = c.id_sesion()
    estado, ruta, cuerpo, cabeceras = c.pedir('/acciones/ingresar.jsp', {'csrf':csrf,'correo':estudiante['correo'],'contrasena':clave_cuenta})
    assert estado == 200 and '/panel.jsp' in ruta and 'Estudiante de prueba' in cuerpo, ('Ingreso fallido', ruta)
    assert c.id_sesion() != id_previo, 'No rotó el identificador de sesión'
    assert 'no-store' in cabeceras.get('Cache-Control',''), 'Falta protección de caché'
    assert c.pedir('/cuenta.jsp')[0] == 200
    assert c.pedir('/proyecto.jsp?id=999999')[0] == 403, 'Permitió consultar otro proyecto'
    assert c.pedir('/WEB-INF/comun/seguridad.jsp')[0] == 404, 'Expuso una vista privada'
    for privada in ['/WEB-INF/vistas/panel.jsp','/WEB-INF/controladores/panel.jsp','/WEB-INF/modelo/panel/proyectos.jsp']:
        assert c.pedir(privada)[0] == 404, 'Permitió acceder directamente a una capa MVC'
    datos = estudiante | {'csrf':c.token('/registro.jsp'),'correo':'privilegios@prueba.invalid','rol':'comite'}
    _, ruta, _, _ = c.pedir('/acciones/registrar.jsp', datos)
    assert '/registro.jsp' in ruta and sql("SELECT count(*) FROM grado.usuario WHERE correo='privilegios@prueba.invalid';").strip() == '0', 'Permitió autorregistro de Comité'
    docente = Cliente(); t = docente.token('/registro.jsp?tipo=docente')
    datos = estudiante | {'csrf':t,'tipo':'docente','rol':'director','nombre':'Docente de prueba',
        'correo':'docente@prueba.invalid','areas':'Software, Datos','lineas':'Sistemas de información',
        'cursos':'Ingeniería de software','titulos':'Maestría','temas':'Arquitectura','modalidad':['desarrollo_software','proyecto_investigacion']}
    _, ruta, _, _ = docente.pedir('/acciones/registrar.jsp', datos)
    assert 'aviso=registro' in ruta, ('No registró el docente', ruta)
    assert sql("SELECT count(*) FROM grado.docente_area da JOIN grado.usuario u ON u.id=da.docente_id WHERE u.correo='docente@prueba.invalid';").strip() == '2'
    t = docente.token(); assert '/panel.jsp' in docente.pedir('/acciones/ingresar.jsp',{'csrf':t,'correo':datos['correo'],'contrasena':clave_cuenta})[1]
    assert 'Perfil docente' in docente.pedir('/cuenta.jsp')[2]
    sql("UPDATE grado.usuario SET estado='inactivo' WHERE correo='docente@prueba.invalid';")
    assert '/ingresar.jsp' in docente.pedir('/panel.jsp')[1], 'No revocó el acceso a una cuenta inactiva'
    t = c.token('/cuenta.jsp'); assert '/ingresar.jsp' in c.pedir('/acciones/salir.jsp',{'csrf':t})[1]
    assert '/ingresar.jsp' in c.pedir('/panel.jsp')[1], 'Persistió la sesión tras salir'
    assert sql('SELECT count(*) FROM grado.sesion_acceso WHERE revocada;').strip() != '0'
    print('OK: instalación SQL, hashes, registro estudiantil/docente, activación, autenticación, CSRF, inyección SQL, rotación de sesión, acceso privado, perfil, cuenta inactiva y cierre de sesión.')
    (herramientas/'resultado-pruebas-acceso.json').write_text(json.dumps({'resultado':'OK','base':'grado_pruebas','host':BASE},indent=2),encoding='utf-8')

if __name__ == '__main__': comprobar()
