"""Prueba dos Tomcat y reinicios SOLO contra grado_pruebas; no lee .env."""
import json
import secrets
import time
import urllib.request
import pruebas_acceso as p


def verificar():
    nombre = 'grado-sesion-' + secrets.token_hex(4)
    principal = p.ejecutar(p.DOCKER + ['ps', '-q', 'app_pruebas']).strip()
    info = json.loads(p.ejecutar(['docker', 'inspect', principal]))[0]
    red = next(iter(info['NetworkSettings']['Networks']))
    imagen = info['Image']
    base_anterior = p.BASE
    clave = secrets.token_hex(12)
    correo = 'sesiones-' + secrets.token_hex(5) + '@prueba.invalid'
    c = p.Cliente()

    def pedir(base, ruta, datos=None):
        p.BASE = base
        return c.pedir(ruta, datos)

    def esperar(base):
        for _ in range(30):
            try:
                if pedir(base, '/salud.jsp')[0] == 200:
                    return
            except OSError:
                pass
            time.sleep(1)
        raise AssertionError('Instancia no disponible')

    try:
        p.ejecutar(['docker', 'run', '-d', '--name', nombre, '--network', red,
                    '--env-file', str(p.RAIZ / '.tools/pruebas.env'),
                    '-p', '127.0.0.1:18083:8080', imagen])
        esperar('http://127.0.0.1:18083')
        p.BASE = base_anterior
        csrf = c.token('/registro.jsp')
        id_inicial = c.id_sesion()
        datos = dict(csrf=csrf, tipo='estudiante', rol='estudiante',
                     nombre='Prueba sesiones compartidas', correo=correo,
                     contrasena=clave, confirmacion=clave)
        # GET del formulario en A, POST en B con la misma cookie y CSRF.
        estado, ruta, _, _ = pedir('http://127.0.0.1:18083', '/acciones/registrar.jsp', datos)
        assert estado == 200 and 'aviso=registro' in ruta, ('Registro entre instancias', ruta)
        assert c.id_sesion() == id_inicial, 'Perdió la sesión al cambiar de instancia'
        p.BASE = base_anterior
        csrf = c.token()
        estado, ruta, _, _ = pedir('http://127.0.0.1:18083', '/acciones/ingresar.jsp',
                                  dict(csrf=csrf, correo=correo, contrasena=clave))
        assert estado == 200 and '/panel.jsp' in ruta, ('Login entre instancias', ruta)
        assert c.id_sesion() != id_inicial, 'No rotó sesión al autenticar'
        for base in [base_anterior, 'http://127.0.0.1:18083'] * 3:
            assert '/panel.jsp' in pedir(base, '/panel.jsp')[1], 'Perdió autenticación entre instancias'
        p.ejecutar(p.DOCKER + ['restart', 'app_pruebas'])
        esperar(base_anterior)
        assert '/panel.jsp' in pedir(base_anterior, '/panel.jsp')[1], 'Perdió sesión tras reinicio'
        p.BASE = base_anterior
        csrf = c.token('/cuenta.jsp')
        assert pedir('http://127.0.0.1:18083', '/acciones/salir.jsp', dict(csrf=csrf))[0] == 200
        assert '/ingresar.jsp' in pedir(base_anterior, '/panel.jsp')[1], 'Logout no afectó la otra instancia'
        p.BASE = base_anterior
        csrf = c.token('/registro.jsp')
        assert pedir('http://127.0.0.1:18083', '/acciones/registrar.jsp', datos | {'csrf':'incorrecto'})[0] == 403
        assert pedir('http://127.0.0.1:18083', '/acciones/registrar.jsp', datos | {'csrf':''})[0] == 403
        # El servidor informa el límite en bytes antes de intentar el registro.
        resultado = pedir('http://127.0.0.1:18083', '/acciones/registrar.jsp',
                          datos | {'csrf':csrf, 'contrasena':'á'*40, 'confirmacion':'á'*40})
        assert '72 bytes UTF-8' in resultado[2], 'No explicó el límite UTF-8'
        assert p.sql("SELECT estado FROM grado.usuario WHERE correo='"+correo+"';").strip() == 'activo'
        op = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        req = urllib.request.Request(base_anterior + '/ingresar.jsp', headers={'X-Forwarded-Proto':'https'})
        with op.open(req, timeout=15) as r:
            cookies = ';'.join(r.headers.get_all('Set-Cookie', []))
            assert all(v in cookies for v in ('Secure', 'HttpOnly', 'SameSite=Lax')), 'Faltan flags de cookie detrás de proxy HTTPS'
        print('OK: GET/POST entre dos instancias, registro autoactivo, CSRF, rotación, navegación alternada, reinicio, logout y límite UTF-8.')
    finally:
        p.BASE = base_anterior
        p.ejecutar(['docker', 'rm', '-f', nombre])


if __name__ == '__main__':
    verificar()
