"""Matriz HTTP por rol sobre los fixtures locales de las suites integrales.

No lee .env ni utiliza Supabase. Ejecutar después de pruebas_tareas.py.
"""
import html.parser
import json
import secrets
from datetime import datetime, timezone
from pruebas_acceso import Cliente, RAIZ, sql
from pruebas_flujo_inicial import literal

ROLES=['estudiante','director','evaluador','comite','secretaria']
TODOS=set(ROLES)
ACCIONES={
 'docentes-asignar':{'comite'}, 'documentos-enviar':{'estudiante'},
 'acta-crear':{'comite'}, 'acta-aprobar':{'comite'},
 'cuenta-administrar':{'comite'}, 'final-cerrar':{'comite'},
 'final-guardar':{'estudiante','director'}, 'idea-crear':{'estudiante','director'},
 'idea-decidir':{'comite'}, 'mensajes-leer':TODOS,
 'mensaje-enviar':{'estudiante','director'}, 'pago-decidir':{'comite'},
 'pago-enviar':{'estudiante'}, 'proyecto-crear':{'estudiante'},
 'proyecto-pausa':{'comite'}, 'revision-decidir':{'director','evaluador','comite'},
 'solicitud-crear':{'estudiante'}, 'solicitud-decidir':{'comite'},
 'aviso-leer':TODOS, 'salir':TODOS,
}

class Tarjetas(html.parser.HTMLParser):
 def __init__(self): super().__init__(); self.urls=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='a' and a.get('class')=='acceso-modulo': self.urls.append(a['href'])

def verificar(clave=None):
    # psql está fijado en pruebas_acceso.sql al servicio bd_pruebas/grado_pruebas.
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    if clave is None:
        clave=secrets.token_hex(16)
        sql("UPDATE grado.usuario SET contrasena_hash=grado.crear_hash_contrasena("+literal(clave)+") WHERE correo IN ('alumno@flujo.invalid','director@flujo.invalid','evaluador@flujo.invalid','comite@flujo.invalid','secretaria@flujo.invalid');")
    pid=sql("SELECT id FROM grado.proyecto WHERE estado='finalizado' ORDER BY id LIMIT 1;").strip()
    cerrado=sql("SELECT id FROM grado.proyecto WHERE titulo='demora';").strip()
    sin_docentes=sql("SELECT id FROM grado.proyecto WHERE titulo='Segunda idea';").strip()
    activo=sql("SELECT id FROM grado.proyecto WHERE titulo='pausado';").strip()
    idea=sql('SELECT idea_id FROM grado.proyecto WHERE id='+cerrado+';').strip()
    version=sql('SELECT min(v.id) FROM grado.documento_version v JOIN grado.documento d ON d.id=v.documento_id WHERE d.proyecto_id='+pid+';').strip()
    acta=sql('SELECT id FROM grado.acta WHERE aprobada_en IS NOT NULL ORDER BY id LIMIT 1;').strip()
    uid=sql("SELECT id FROM grado.usuario WHERE correo='alumno@flujo.invalid';").strip()
    vistas={
      '/panel.jsp':TODOS,'/cuenta.jsp':TODOS,'/ideas.jsp':TODOS,'/proyectos.jsp':TODOS,
      '/avisos.jsp':TODOS,'/tareas.jsp':TODOS,'/idea-nueva.jsp':{'estudiante','director'},
      '/proyecto-nuevo.jsp?idea='+idea:{'estudiante'},'/idea.jsp?id='+idea:TODOS,
      '/usuarios.jsp':{'comite'},'/usuario.jsp?usuario='+uid:{'comite'},
      '/documento.jsp?version='+version:TODOS,'/acta.jsp?acta='+acta:TODOS,
    }
    for vista in ['proyecto','resumen','pago','final','solicitudes','historial','actas','mensajes']:
        vistas['/'+vista+'.jsp?id='+pid]=TODOS
    for tipo in ['propuesta','informe']:
        vistas['/seguimiento.jsp?id='+pid+'&tipo='+tipo]=TODOS
    resultados=[]
    def comprobar(condicion,detalle):
        assert condicion,detalle
        resultados.append(detalle)
    for rol in ROLES:
        nombre='alumno' if rol=='estudiante' else rol
        c=Cliente(); status,url,html,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':clave})
        comprobar(status==200 and url.endswith('/panel.jsp'),rol+': inicio de sesión')
        tarjetas=Tarjetas(); tarjetas.feed(html)
        comprobar(('/usuarios.jsp' in tarjetas.urls)==(rol=='comite'),rol+': tarjeta de administración')
        comprobar(('/idea-nueva.jsp' in tarjetas.urls)==(rol in ['estudiante','director']),rol+': tarjeta de propuesta')
        for ruta,permitidos in vistas.items():
            status,url,body,_=c.pedir(ruta)
            comprobar(status==(200 if rol in permitidos else 403),rol+': vista '+ruta)
            if status==200: comprobar('/no-disponible.jsp' not in url and '<c:' not in body,rol+': renderizado '+ruta)
        token=c.token('/cuenta.jsp')
        for accion,permitidos in ACCIONES.items():
            ruta='/acciones/'+accion+'.jsp'
            comprobar(c.pedir(ruta)[0]==403,rol+': GET bloqueado '+accion)
            comprobar(c.pedir(ruta,{'csrf':'incorrecto'})[0]==403,rol+': CSRF bloqueado '+accion)
            if rol not in permitidos:
                comprobar(c.pedir(ruta,{'csrf':token,'id':pid,'usuario':uid,'idea':idea,'acta':acta,'tipo':'propuesta','decision':'aprobado','reporte':'No autorizado'})[0]==403,rol+': acción ajena bloqueada '+accion)
        if rol=='secretaria':
            for proyecto in [cerrado,activo,sin_docentes]:
                for vista in ['proyecto','resumen']:
                    status,_,body,_=c.pedir('/'+vista+'.jsp?id='+proyecto)
                    comprobar(status==200 and '<dt>Director</dt>' in body and '<dt>Evaluador</dt>' in body,'secretaria: docentes '+vista+' '+proyecto)
                    if proyecto==cerrado: comprobar('director-nuevo' in body and 'evaluador-nuevo' in body,'secretaria: última asignación '+vista)
                    if proyecto==sin_docentes: comprobar(body.count('Por asignar')>=2,'secretaria: docentes por asignar '+vista)
                status,_,body,_=c.pedir('/proyecto.jsp?id='+proyecto)
                for fila in sql('SELECT f.codigo,(pf.iniciada_en IS NOT NULL)::text FROM grado.fase f LEFT JOIN grado.proyecto_fase pf ON pf.fase_codigo=f.codigo AND pf.proyecto_id='+proyecto+';').strip().splitlines():
                    codigo,iniciada=fila.split('|')
                    comprobar(('id="fase-'+codigo+'"' in body)==(iniciada=='true'),'secretaria: pop-up iniciado '+codigo+' '+proyecto)
            comprobar('mensaje privado' not in c.pedir('/mensajes.jsp?id='+pid)[2],'secretaria: no lee mensajes privados ajenos')
        if rol in ['estudiante','director']:
            ruta='/mensajes.jsp?id='+pid
            body=c.pedir(ruta)[2]
            comprobar('mensaje privado' in body,rol+': conserva correspondencia histórica')
            antes=sql('SELECT count(*) FROM grado.mensaje;').strip()
            destino=sql("SELECT id FROM grado.usuario WHERE correo="+literal(('director' if rol=='estudiante' else 'pareja')+'@flujo.invalid')+';').strip()
            c.pedir('/acciones/mensaje-enviar.jsp',{'csrf':c.token(ruta),'id':pid,'destinatario':destino,'contenido':'Envío no permitido tras cierre'})
            comprobar(sql('SELECT count(*) FROM grado.mensaje;').strip()==antes,rol+': envío bloqueado tras cierre/retiro')
        print('OK matriz de permisos: '+rol,flush=True)
    anonimo=Cliente()
    for ruta in vistas:
        status,url,_,_=anonimo.pedir(ruta)
        comprobar(status==200 and '/ingresar.jsp' in url,'sin sesión: '+ruta)
    for archivo in (RAIZ/'src/main/webapp/WEB-INF').rglob('*.jsp'):
        ruta='/'+archivo.relative_to(RAIZ/'src/main/webapp').as_posix()
        comprobar(anonimo.pedir(ruta)[0]==404,'archivo interno protegido: '+ruta)
    status,url,_,_=anonimo.pedir('/')
    comprobar(status==200 and url.endswith('/ingresar.jsp'),'entrada principal al login')
    comprobar(anonimo.pedir('/registro.jsp')[0]==200,'registro estudiantil disponible')
    comprobar(anonimo.pedir('/registro.jsp?tipo=docente')[0]==200,'registro docente disponible')
    # El inventario evita omitir una acción nueva en futuras comprobaciones.
    reales={p.stem for p in (RAIZ/'src/main/webapp/acciones').glob('*.jsp')}
    comprobar(reales==set(ACCIONES)|{'ingresar','registrar'},'inventario completo de acciones')
    salida={'resultado':'OK','fecha_utc':datetime.now(timezone.utc).isoformat(),'base':'grado_pruebas','roles':ROLES,'comprobaciones':len(resultados),'detalles':resultados}
    (RAIZ/'.tools/resultado-pruebas-permisos.json').write_text(json.dumps(salida,ensure_ascii=False,indent=2),encoding='utf-8')
    print('OK: '+str(len(resultados))+' comprobaciones adicionales de vistas, acciones, CSRF, sesión, capas privadas y cambios recientes.')
    return salida

if __name__=='__main__': verificar()
