"""Flujo real HTTP y concurrencia en grado-pruebas. Nunca conecta con Supabase."""
import concurrent.futures
import json
import secrets
import urllib.parse
from pruebas_acceso import Cliente, RAIZ, comprobar, sql
from pruebas_resumen import ver_resumen
from pruebas_tareas import ver_tareas

def literal(valor):
    return "'"+str(valor).replace("'", "''")+"'"

def flujo():
    clave = secrets.token_hex(10)
    hash_clave = sql('SELECT grado.crear_hash_contrasena('+literal(clave)+');').strip()
    def cuenta(nombre,rol):
        return sql('INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES ('+
            ','.join(map(literal,[nombre,nombre+'@flujo.invalid',hash_clave,rol,'activo']))+') RETURNING id;').splitlines()[0]
    alumno=cuenta('alumno','estudiante'); pareja=cuenta('pareja','estudiante'); ajeno=cuenta('ajeno','estudiante')
    comite=cuenta('comite','comite'); director=cuenta('director','director'); evaluador=cuenta('evaluador','evaluador')
    no_apto=cuenta('noapto','evaluador')
    modalidad=sql("SELECT id FROM grado.modalidad WHERE codigo='desarrollo_software';").strip()
    for docente in [director,evaluador]:
        sql(f"INSERT INTO grado.perfil_docente VALUES ({docente},'Cursos','Títulos','Temas'); "
            f"INSERT INTO grado.docente_area SELECT {docente},id FROM grado.area_experiencia WHERE nombre='Software'; "
            f"INSERT INTO grado.docente_linea SELECT {docente},id FROM grado.linea_investigacion WHERE nombre='Sistemas de información'; "
            f"INSERT INTO grado.docente_modalidad VALUES ({docente},{modalidad});")
    sql(f"INSERT INTO grado.perfil_docente VALUES ({no_apto},'Cursos','Títulos','Temas');")
    def ingreso(nombre):
        c=Cliente(); estado,ruta,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':clave})
        assert estado==200 and '/panel.jsp' in ruta, ('Ingreso',nombre,ruta)
        return c
    estudiante=ingreso('alumno'); segundo=ingreso('pareja'); tercero=ingreso('ajeno'); revisor=ingreso('comite')
    def post(c,ruta,datos,pagina):
        estado,url,cuerpo,_=c.pedir('/acciones/'+ruta,dict(datos,csrf=c.token(pagina)))
        assert estado==200, ('POST',ruta,estado,url,cuerpo[:250])
        assert 'no-disponible' not in url and '/error.jsp' not in url, ('POST',ruta,url)
        return url,cuerpo
    titulo='Gestión de proyectos <img src=x onerror=alert(1)>'
    datos={'titulo':titulo,'modalidad':modalidad,'area':'Software','linea':'Sistemas de información',
        'descripcion':'Seguimiento académico','objetivos':'Organizar entregas','tecnologias':'PostgreSQL y JSTL'}
    assert estudiante.pedir('/ideas.jsp')[0]==200
    url,cuerpo=post(estudiante,'idea-crear.jsp',datos,'/idea-nueva.jsp')
    idea=urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)['id'][0]
    assert '&lt;img' in cuerpo and '<img src=x' not in cuerpo, 'XSS en idea'
    assert tercero.pedir('/idea.jsp?id='+idea)[0]==403, 'Expuso idea pendiente'
    _,cuerpo=post(estudiante,'proyecto-crear.jsp',{'idea':idea,'nombre':'Alumno'},'/cuenta.jsp')
    assert sql('SELECT count(*) FROM grado.proyecto;').strip()=='0', 'Creó proyecto sin aprobar idea'
    assert estudiante.pedir('/acciones/idea-decidir.jsp',{'csrf':estudiante.token('/cuenta.jsp'),'id':idea,'decision':'aprobada','reporte':'No autorizado'})[0]==403
    _,cuerpo=post(revisor,'idea-decidir.jsp',{'id':idea,'decision':'aprobada','reporte':'Idea viable'},'/idea.jsp?id='+idea)
    assert 'La decisión quedó registrada' in cuerpo
    assert tercero.pedir('/idea.jsp?id='+idea)[0]==200
    assert 'director' in cuerpo and 'evaluador' in cuerpo, 'No mostró aptos'
    proyecto_datos={'idea':idea,'nombre':'Alumno','documento':'101','telefono':'12345','pareja_correo':'pareja@flujo.invalid',
        'pareja_nombre':'Pareja','pareja_documento':'202','director':director}
    url,cuerpo=post(estudiante,'proyecto-crear.jsp',proyecto_datos,'/proyecto-nuevo.jsp?idea='+idea)
    assert '/pago.jsp' in url and 'Idea reservada' in cuerpo, ('Creación',url,cuerpo[-300:])
    proyecto=urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)['id'][0]
    pago='/pago.jsp?id='+proyecto
    ver_resumen(estudiante,proyecto,['Presentar el conjunto de Pago','Comprobante de pago'])
    ver_tareas(estudiante,['Presentar el conjunto · Pago'])
    assert segundo.pedir(pago)[0]==200 and tercero.pedir(pago)[0]==403, 'Error permisos de participantes'
    assert sql(f'SELECT count(*) FROM grado.participante_proyecto WHERE proyecto_id={proyecto};').strip()=='2'
    post(tercero,'proyecto-crear.jsp',{'idea':idea,'nombre':'Ajeno'},'/cuenta.jsp')
    assert sql('SELECT count(*) FROM grado.proyecto;').strip()=='1', 'Duplicó reserva'
    post(revisor,'docentes-asignar.jsp',{'id':proyecto,'director':director,'evaluador':evaluador},pago)
    assert sql('SELECT count(*) FROM grado.asignacion_proyecto;').strip()=='0', 'Asignó antes de aprobar pago'
    post(estudiante,'pago-enviar.jsp',{'id':proyecto,'comprobante':'javascript:alert(1)'},pago)
    assert sql('SELECT count(*) FROM grado.entrega_revision;').strip()=='0', 'Aceptó URL peligrosa'
    assert tercero.pedir('/acciones/pago-enviar.jsp',{'csrf':tercero.token('/cuenta.jsp'),'id':proyecto,'comprobante':'https://ejemplo.invalid/ajeno'})[0]==403
    assert sql('SELECT count(*) FROM grado.entrega_revision;').strip()=='0', 'Permitió modificar proyecto ajeno'
    _,cuerpo=post(estudiante,'pago-enviar.jsp',{'id':proyecto,'comprobante':'https://ejemplo.invalid/pago?archivo=1&v=2','adicionales':'https://ejemplo.invalid/a\nhttps://ejemplo.invalid/b'},pago)
    assert 'Conjunto enviado' in cuerpo, ('Presentar',cuerpo[-300:])
    entrega=sql(f'SELECT id FROM grado.entrega_revision WHERE proyecto_id={proyecto} ORDER BY numero DESC LIMIT 1;').strip()
    assert sql('SELECT count(*) FROM grado.entrega_documento_version;').strip()=='3'
    post(estudiante,'pago-enviar.jsp',{'id':proyecto,'comprobante':'https://ejemplo.invalid/duplicado'},pago)
    assert sql('SELECT count(*) FROM grado.entrega_revision;').strip()=='1', 'Duplicó envío en revisión'
    post(revisor,'pago-decidir.jsp',{'id':proyecto,'entrega':entrega,'decision':'rechazado','reporte':'Corrige el comprobante <b>por favor</b>'},pago)
    assert '&lt;b&gt;por favor&lt;/b&gt;' in estudiante.pedir(pago)[2], 'XSS en reporte'
    assert sql('SELECT count(*) FROM grado.plazo_correccion;').strip()=='1'
    post(segundo,'pago-enviar.jsp',{'id':proyecto,'comprobante':'https://ejemplo.invalid/pago-corregido','adicionales':'https://ejemplo.invalid/a\nhttps://ejemplo.invalid/b'},pago)
    assert sql('SELECT count(*) FROM grado.entrega_documento_version;').strip()=='6', 'No conservó conjunto completo/versiones'
    nueva=sql(f'SELECT id FROM grado.entrega_revision WHERE proyecto_id={proyecto} ORDER BY numero DESC LIMIT 1;').strip()
    post(revisor,'pago-decidir.jsp',{'id':proyecto,'entrega':entrega,'decision':'aprobado','reporte':'Viejo'},pago)
    assert sql('SELECT count(*) FROM grado.datos_pago WHERE aprobado_en IS NOT NULL;').strip()=='0', 'Aprobó entrega antigua'
    post(revisor,'pago-decidir.jsp',{'id':proyecto,'entrega':nueva,'decision':'aprobado','reporte':'Conjunto correcto'},pago)
    ver_resumen(revisor,proyecto,['Asignar el director y el evaluador','El conjunto de Pago ya fue aprobado'])
    ver_tareas(revisor,['Asignar director y evaluador'])
    post(revisor,'docentes-asignar.jsp',{'id':proyecto,'director':director,'evaluador':director},pago)
    post(revisor,'docentes-asignar.jsp',{'id':proyecto,'director':director,'evaluador':no_apto},pago)
    assert sql('SELECT count(*) FROM grado.asignacion_proyecto;').strip()=='0', 'Aceptó docentes sin coincidencia'
    _,cuerpo=post(revisor,'docentes-asignar.jsp',{'id':proyecto,'director':director,'evaluador':evaluador},pago)
    assert 'El proyecto avanzó a Propuesta I' in cuerpo, 'No asignó docentes'
    assert sql("SELECT fase_codigo FROM grado.proyecto_fase WHERE finalizada_en IS NULL AND iniciada_en IS NOT NULL;").strip()=='propuesta_1'
    assert sql('SELECT count(*) FROM grado.asignacion_proyecto;').strip()=='2'
    assert ingreso('director').pedir('/proyecto.jsp?id='+proyecto)[0]==200
    assert sql('SELECT count(*) FROM grado.notificacion;').strip()!='0', 'Faltan notificaciones'
    # Una segunda idea no permite usar un integrante que ya tiene proyecto.
    url,_=post(estudiante,'idea-crear.jsp',datos|{'titulo':'Segunda idea'},'/idea-nueva.jsp')
    otra=urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)['id'][0]
    post(revisor,'idea-decidir.jsp',{'id':otra,'decision':'aprobada','reporte':'Viable'},'/idea.jsp?id='+otra)
    post(tercero,'proyecto-crear.jsp',{'idea':otra,'nombre':'Ajeno','pareja_correo':'pareja@flujo.invalid','pareja_nombre':'Pareja'},'/cuenta.jsp')
    assert sql('SELECT count(*) FROM grado.proyecto;').strip()=='1', 'Permitió dos proyectos por estudiante'
    # Carrera de reserva: dos estudiantes distintos intentan tomar la misma idea.
    carrera=cuenta('carrera','estudiante'); cuarto=ingreso('carrera')
    def reservar(c,nombre):
        return post(c,'proyecto-crear.jsp',{'idea':otra,'nombre':nombre},'/cuenta.jsp')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda par: reservar(*par),[(tercero,'Ajeno'),(cuarto,'Carrera')]))
    assert sql(f'SELECT count(*) FROM grado.proyecto WHERE idea_id={otra};').strip()=='1', 'Reserva concurrente duplicada'
    # UI de lectura para perfiles sin operaciones de Comité.
    secretaria=cuenta('secretaria','secretaria'); lectura=ingreso('secretaria')
    assert lectura.pedir(pago)[0]==200
    ver_tareas(lectura,['No hay tareas disponibles'],['Atender →'])
    assert lectura.pedir('/acciones/pago-decidir.jsp',{'csrf':lectura.token(pago),'id':proyecto,'entrega':nueva,'decision':'aprobado','reporte':'No'})[0]==403
    print('OK: ideas, aprobación, XSS, reserva concurrente, pareja, proyecto único, enlaces, pago, rechazo, reenvío completo, historial, notificaciones y asignación por coincidencia.')
    (RAIZ/'.tools/resultado-pruebas-flujo.json').write_text(json.dumps({'resultado':'OK','base':'grado_pruebas'},indent=2),encoding='utf-8')
    return {'clave':clave,'proyecto':proyecto,'director':director,'evaluador':evaluador,'comite':comite,'alumno':alumno,'pareja':pareja}

if __name__=='__main__':
    comprobar()
    flujo()
