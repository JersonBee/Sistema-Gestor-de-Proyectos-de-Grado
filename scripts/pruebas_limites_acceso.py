"""Límite de intentos y expiración real de acceso; solo grado_pruebas local."""
import secrets
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

def verificar_limites_acceso():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    prefijo='QA-Acceso-'+secrets.token_hex(6);correo=prefijo.lower()+'@prueba.invalid';clave=secrets.token_hex(12)
    uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES("+literal(prefijo)+','+literal(correo)+',grado.crear_hash_contrasena('+literal(clave)+"),'estudiante','activo') RETURNING id;").splitlines()[0]
    huella="encode(extensions.digest("+literal(correo)+",'sha256'),'hex')"
    try:
        c=Cliente()
        for n in range(10):
            status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo.upper() if n%2 else correo,'contrasena':'Incorrecta-'+str(n)})
            assert status==200 and 'error=credenciales' in url, 'Aceptó una contraseña incorrecta'
        assert sql(f'SELECT count(*) FROM grado.intento_acceso WHERE correo_hash={huella};').strip()=='10','Cambiar mayúsculas eludió el contador'
        status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and 'error=credenciales' in url,'El límite no bloqueó el siguiente ingreso'
        assert sql(f'SELECT count(*) FROM grado.sesion_acceso WHERE usuario_id={uid};').strip()=='0'
        sql(f"UPDATE grado.intento_acceso SET creado_en=CURRENT_TIMESTAMP-interval '16 minutes' WHERE correo_hash={huella};")
        status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and url.endswith('/panel.jsp'),'El límite no se liberó después de su ventana'
        assert sql(f'SELECT count(*) FROM grado.intento_acceso WHERE correo_hash={huella};').strip()=='0'
        sql(f"UPDATE grado.sesion_acceso SET vence_en=CURRENT_TIMESTAMP-interval '1 second' WHERE usuario_id={uid};")
        status,url,_,_=c.pedir('/panel.jsp')
        assert status==200 and '/ingresar.jsp' in url and 'aviso=sesion' in url,'Una sesión expirada conservó acceso'
        status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and url.endswith('/panel.jsp'),'No permitió ingresar después de expirar la sesión'
        status,url,_,_=c.pedir('/acciones/salir.jsp',{'csrf':c.token('/cuenta.jsp')})
        assert status==200 and '/ingresar.jsp' in url
        assert sql(f'SELECT count(*) FROM grado.sesion_acceso WHERE usuario_id={uid} AND NOT revocada AND vence_en>CURRENT_TIMESTAMP;').strip()=='0','Logout dejó acceso vigente'
        print('OK: diez intentos, correo en mayúsculas, liberación tras la ventana de quince minutos, expiración, nuevo ingreso y logout.')
    finally:
        sql(f'DELETE FROM grado.intento_acceso WHERE correo_hash={huella}; DELETE FROM grado.sesion_acceso WHERE usuario_id={uid}; DELETE FROM grado.usuario WHERE id={uid};')

if __name__=='__main__': verificar_limites_acceso()
