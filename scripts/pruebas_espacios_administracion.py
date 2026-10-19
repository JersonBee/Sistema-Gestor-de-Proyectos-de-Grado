"""Perfiles vacíos y listas con espacios al administrar cuentas; solo grado_pruebas."""
import secrets
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

def verificar_espacios_administracion():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    clave=secrets.token_hex(12);prefijo='QA-Espacios-'+secrets.token_hex(6);ids=[]
    try:
        for rol in ('comite','estudiante'):
            uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES("+literal(prefijo+' '+rol)+','+literal(prefijo.lower()+rol+'@prueba.invalid')+',grado.crear_hash_contrasena('+literal(clave)+'),'+literal(rol)+",'activo') RETURNING id;").splitlines()[0]
            ids.append(uid)
        comite,estudiante=ids;c=Cliente()
        assert c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':prefijo.lower()+'comite@prueba.invalid','contrasena':clave})[0]==200
        pagina='/usuario.jsp?usuario='+estudiante
        datos={'usuario':estudiante,'rol':'director','estado':'activo','areas':'Software','lineas':'Sistemas de información','modalidad':['desarrollo_software'],'cursos':'Cursos','titulos':'Títulos','temas':'Temas'}
        for campo in ('cursos','titulos','temas','areas','lineas'):
            status,_,body,_=c.pedir('/acciones/cuenta-administrar.jsp',datos|{campo:'\t\r\n','csrf':c.token(pagina)})
            assert status==200
            assert sql(f'SELECT rol_codigo FROM grado.usuario WHERE id={estudiante};').strip()=='estudiante', 'Promovio una cuenta con '+campo+' vacio'
            assert sql(f'SELECT count(*) FROM grado.perfil_docente WHERE usuario_id={estudiante};').strip()=='0','Dejo un perfil parcial'
        status,_,body,_=c.pedir('/acciones/cuenta-administrar.jsp',datos|{'areas':'Software, \t, Datos','lineas':'Sistemas de información, \t','csrf':c.token(pagina)})
        assert status==200 and 'Cuenta actualizada' in body
        assert sql(f'SELECT rol_codigo FROM grado.usuario WHERE id={estudiante};').strip()=='director'
        assert sql(f'SELECT count(*) FROM grado.docente_area WHERE docente_id={estudiante};').strip()=='2'
        assert sql(f'SELECT count(*) FROM grado.docente_linea WHERE docente_id={estudiante};').strip()=='1'
        print('OK: administración rechaza cinco campos vacíos sin cambios parciales y acepta perfil válido sin entradas en blanco.')
    finally:
        if ids:
            lista=','.join(ids)
            sql(f'''DELETE FROM grado.docente_area WHERE docente_id IN({lista}); DELETE FROM grado.docente_linea WHERE docente_id IN({lista}); DELETE FROM grado.docente_modalidad WHERE docente_id IN({lista}); DELETE FROM grado.perfil_docente WHERE usuario_id IN({lista}); DELETE FROM grado.evento_auditoria WHERE actor_id IN({lista}); DELETE FROM grado.sesion_acceso WHERE usuario_id IN({lista}); DELETE FROM grado.usuario WHERE id IN({lista});''')

if __name__=='__main__': verificar_espacios_administracion()
