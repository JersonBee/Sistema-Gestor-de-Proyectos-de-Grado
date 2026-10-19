"""Casos de registro docente y entradas inválidas; solo grado_pruebas local."""
import secrets
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

def verificar_registro():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    clave=secrets.token_hex(12); prefijo=secrets.token_hex(5)
    base={'tipo':'docente','rol':'evaluador','nombre':'Evaluador de validación','contrasena':clave,'confirmacion':clave,
      'areas':'Validación Software, Validación Datos','lineas':'Validación Investigación, Validación Sistemas',
      'cursos':'Curso de prueba','titulos':'Título de prueba','temas':'Investigación',
      'modalidad':['desarrollo_software','proyecto_investigacion']}
    def registrar(sufijo,cambios):
        correo=prefijo+sufijo+'@validacion.invalid'; c=Cliente()
        datos=base|{'correo':correo}|cambios
        estado,url,html,_=c.pedir('/acciones/registrar.jsp',datos|{'csrf':c.token('/registro.jsp?tipo=docente')})
        assert estado==200 and '/no-disponible.jsp' not in url,('Registro',sufijo,estado,url)
        return correo,c,url,html
    invalidos=[{'nombre':'\t\t'}, {'cursos':'\t\r\n'}, {'titulos':'\t\n'}, {'temas':'\r\n'}, {'areas':', , ,'}, {'lineas':',,,'}, {'areas':' \t,\n, '}, {'modalidad':['inexistente']},
      {'cursos':''}, {'rol':'comite'}, {'rol':'secretaria'}, {'confirmacion':'diferente'}, {'contrasena':'corta','confirmacion':'corta'}]
    for n,datos in enumerate(invalidos):
        correo,_,url,_=registrar('invalido'+str(n),datos)
        assert '/registro.jsp' in url and 'aviso=registro' not in url,('Aceptó registro inválido',datos)
        assert sql('SELECT count(*) FROM grado.usuario WHERE correo='+literal(correo)+';').strip()=='0',('Creó cuenta inválida',n)
    correo,c,url,_=registrar('valido',{'areas':'\tValidación Software\t, \t, Validación Datos\t','lineas':'Validación Investigación, \t, Validación Sistemas'})
    assert 'aviso=registro' in url,'No completó el registro de Evaluador'
    uid=sql('SELECT id FROM grado.usuario WHERE correo='+literal(correo)+';').strip()
    assert sql('SELECT estado FROM grado.usuario WHERE id='+uid+';').strip()=='activo'
    for tabla in ['docente_area','docente_linea','docente_modalidad']:
        assert sql('SELECT count(*) FROM grado.'+tabla+' WHERE docente_id='+uid+';').strip()=='2'
    estado,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
    assert estado==200 and url.endswith('/panel.jsp')
    assert 'Validación Datos' in c.pedir('/cuenta.jsp')[2]
    otro=Cliente()
    estado,url,_,_=otro.pedir('/acciones/registrar.jsp',base|{'correo':correo.upper(),'csrf':otro.token('/registro.jsp?tipo=docente')})
    assert estado==200 and '/registro.jsp' in url
    assert sql('SELECT count(*) FROM grado.usuario WHERE lower(correo)='+literal(correo)+';').strip()=='1'
    print('OK: registro Evaluador/perfil múltiple, áreas/líneas vacías, modalidad inválida, campos obligatorios, roles restringidos, confirmación y duplicados.')

if __name__=='__main__': verificar_registro()
