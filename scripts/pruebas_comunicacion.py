"""Actas, mensajes privados, cuentas y filtros en PostgreSQL local aislado."""
import json
import urllib.parse
from pruebas_acceso import Cliente, RAIZ, comprobar, sql
from pruebas_flujo_inicial import flujo, literal
from pruebas_revisiones import revisiones
from pruebas_final_solicitudes import tramites
from pruebas_resumen import ver_resumen
from pruebas_tareas import ver_tareas

def comunicacion(ctx):
    pid=ctx['proyecto']; clave=ctx['clave']
    def ingreso(nombre):
        c=Cliente()
        estado,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':clave})
        assert estado==200 and '/panel.jsp' in url, ('Ingreso',nombre,url)
        return c
    alumno=ingreso('alumno'); pareja=ingreso('pareja'); director=ingreso('director')
    comite=ingreso('comite'); evaluador=ingreso('evaluador'); secretaria=ingreso('secretaria'); ajeno=ingreso('ajeno')
    def ruta(vista): return '/'+vista+'.jsp?id='+str(pid)
    def post(c,accion,datos,vista='mensajes'):
        estado,url,cuerpo,_=c.pedir('/acciones/'+accion+'.jsp',dict(datos,csrf=c.token(ruta(vista))))
        assert estado==200 and '/no-disponible.jsp' not in url and '/error.jsp' not in url, (accion,estado,url,cuerpo[:150])
        return cuerpo
    def enviar(c,destino,texto): return post(c,'mensaje-enviar',{'id':pid,'destinatario':destino,'contenido':texto})
    # El contenido y las marcas de lectura solo pertenecen a sus participantes.
    privado='mensaje privado <script>alert(1)</script>'
    assert 'Mensaje enviado' in enviar(alumno,ctx['director'],privado)
    ver_tareas(director,['Leer mensajes recibidos'],['mensaje privado'])
    ver_tareas(pareja,ausentes=['Leer mensajes recibidos'])
    mid=sql('SELECT max(id) FROM grado.mensaje;').strip()
    assert '&lt;script&gt;alert(1)&lt;/script&gt;' in director.pedir(ruta('mensajes'))[2]
    for c in [pareja,evaluador,comite,secretaria]:
        estado,_,cuerpo,_=c.pedir(ruta('mensajes'))
        assert estado==200 and 'mensaje privado' not in cuerpo, 'Expuso correspondencia ajena'
    assert ajeno.pedir(ruta('mensajes'))[0]==403
    post(pareja,'mensajes-leer',{'id':pid})
    assert sql(f'SELECT leido_en IS NULL FROM grado.mensaje WHERE id={mid};').strip()=='t'
    assert 'marcados como leídos' in post(director,'mensajes-leer',{'id':pid})
    assert sql(f'SELECT leido_en IS NOT NULL FROM grado.mensaje WHERE id={mid};').strip()=='t'
    ver_tareas(director,ausentes=['Leer mensajes recibidos'])
    assert 'Mensaje enviado' in enviar(director,ctx['alumno'],'Respuesta privada')
    cantidad=sql('SELECT count(*) FROM grado.mensaje;').strip()
    assert 'canal permite' in enviar(alumno,ctx['evaluador'],'No autorizado')
    assert ajeno.pedir('/acciones/mensaje-enviar.jsp',{'csrf':ajeno.token('/cuenta.jsp'),'id':pid,'destinatario':ctx['director'],'contenido':'Ajeno'})[0]==403
    assert evaluador.pedir('/acciones/mensaje-enviar.jsp',{'csrf':evaluador.token(ruta('mensajes')),'id':pid,'destinatario':ctx['alumno'],'contenido':'No'})[0]==403
    assert sql('SELECT count(*) FROM grado.mensaje;').strip()==cantidad
    assert 'mensaje privado' not in comite.pedir(ruta('historial'))[2]
    # CSRF y método protegen todas las nuevas operaciones.
    for accion in ['acta-crear','acta-aprobar','mensaje-enviar','mensajes-leer','cuenta-administrar']:
        assert comite.pedir('/acciones/'+accion+'.jsp',{'csrf':'incorrecto'})[0]==403
        assert comite.pedir('/acciones/'+accion+'.jsp')[0] in [403,405]
    # Actas: borrador privado del Comité, aprobación y consulta autorizada.
    datos={'id':pid,'numero':'ACT-001','fecha':'2026-10-17','descripcion':'Sesión de seguimiento','detalles':'Decisión <b>académica</b>'}
    assert 'Acta registrada' in post(comite,'acta-crear',datos,'actas')
    ver_tareas(comite,['Aprobar el acta pendiente'])
    aid=sql('SELECT max(id) FROM grado.acta;').strip(); detalle='/acta.jsp?acta='+aid
    assert alumno.pedir(detalle)[0]==403
    assert 'Pendiente de aprobación' in comite.pedir(detalle)[2]
    assert 'Ya existe' in post(comite,'acta-crear',datos,'actas')
    assert 'fecha válida' in post(comite,'acta-crear',dict(datos,numero='MALA',fecha='2026-02-30'),'actas')
    assert alumno.pedir('/acciones/acta-aprobar.jsp',{'csrf':alumno.token(ruta('actas')),'acta':aid})[0]==403
    cuerpo=post(comite,'acta-aprobar',{'acta':aid},'actas')
    assert 'Acta aprobada' in cuerpo
    ver_tareas(comite,ausentes=['Aprobar el acta pendiente'])
    for c in [alumno,pareja,director,evaluador,secretaria]:
        estado,_,cuerpo,_=c.pedir(detalle)
        assert estado==200 and '&lt;b&gt;académica&lt;/b&gt;' in cuerpo
    assert ajeno.pedir(detalle)[0]==403
    aprobaciones=sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='aprobar_acta';").strip()
    post(comite,'acta-aprobar',{'acta':aid},'actas')
    assert sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='aprobar_acta';").strip()==aprobaciones
    assert 'Acta aprobada' in alumno.pedir('/avisos.jsp')[2]
    # Pausar bloquea procedimientos, conserva las consultas históricas.
    post(comite,'proyecto-pausa',{'id':pid,'operacion':'pausar','motivo':'Prueba de comunicación'},'proyecto')
    ver_resumen(alumno,pid,['El proyecto está en pausa','Los plazos están suspendidos'],['Revisión hasta:'])
    ver_tareas(alumno,ausentes=['Presentar el conjunto · Propuesta I'])
    assert 'proyecto activo' in enviar(alumno,ctx['director'],'Durante pausa')
    assert 'en pausa' in post(comite,'acta-crear',dict(datos,numero='PAUSA'),'actas')
    assert alumno.pedir(detalle)[0]==200
    post(comite,'proyecto-pausa',{'id':pid,'operacion':'reanudar'},'proyecto')
    # Filtros combinados y autorización no dependen de campos del formulario.
    modalidad=sql(f'SELECT modalidad_id FROM grado.proyecto WHERE id={pid};').strip()
    filtros={'q':pid,'estudiante':'alumno','director':'director','evaluador':'evaluador','modalidad':modalidad,'estado':'activo','fase':'propuesta_1','desde':'2000-01-01','hasta':'2100-01-01'}
    consulta='/proyectos.jsp?'+urllib.parse.urlencode(filtros)
    estado,_,cuerpo,_=comite.pedir(consulta)
    assert estado==200 and 'PROYECTO #'+pid in cuerpo, 'Falló la búsqueda combinada'
    for filtro,valor in filtros.items():
        estado,_,cuerpo,_=comite.pedir('/proyectos.jsp?'+urllib.parse.urlencode({filtro:valor}))
        assert estado==200 and 'PROYECTO #'+pid in cuerpo, ('Falló el filtro',filtro)
    assert 'PROYECTO #'+pid not in ajeno.pedir(consulta)[2]
    assert 'No hay proyectos' in comite.pedir('/proyectos.jsp?q=sin-coincidencias')[2]
    assert 'Revisa las fechas' in comite.pedir('/proyectos.jsp?desde=2026-02-30')[2]
    assert '<script>alert(1)</script>' not in comite.pedir('/proyectos.jsp?q='+urllib.parse.quote('<script>alert(1)</script>'))[2]
    # Administración exclusiva del Comité y revocación de sesiones existentes.
    # Cuenta sin proyecto: ajeno puede ganar la reserva concurrente del flujo.
    uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo) SELECT 'Administrado','administrado@flujo.invalid',contrasena_hash,'estudiante' FROM grado.usuario WHERE id="+str(ctx['alumno'])+' RETURNING id;').splitlines()[0]
    administrado=ingreso('administrado')
    assert alumno.pedir('/usuarios.jsp')[0]==403
    cuenta='/usuario.jsp?usuario='+uid
    assert comite.pedir(cuenta)[0]==200
    def administrar(usuario,rol,estado='activo',extra=None):
        datos={'usuario':usuario,'rol':rol,'estado':estado,'csrf':comite.token('/usuario.jsp?usuario='+str(usuario))}
        if extra: datos.update(extra)
        codigo,url,cuerpo,_=comite.pedir('/acciones/cuenta-administrar.jsp',datos)
        assert codigo==200 and '/usuario.jsp' in url, ('Administración',codigo,url)
        return cuerpo
    assert 'Cuenta actualizada' in administrar(uid,'estudiante','inactivo')
    assert '/ingresar.jsp' in administrado.pedir('/panel.jsp')[1]
    assert 'Cuenta actualizada' in administrar(uid,'estudiante')
    administrado=ingreso('administrado')
    assert 'participación o asignación vigente' in administrar(ctx['director'],'evaluador')
    assert 'propia cuenta activa' in administrar(ctx['comite'],'secretaria')
    assert 'perfil docente' in administrar(uid,'evaluador')
    extra={'areas':'Prueba nueva','lineas':'Línea nueva','modalidad':['desarrollo_software'],'cursos':'Cursos','titulos':'Títulos','temas':'Temas'}
    assert 'Cuenta actualizada' in administrar(uid,'evaluador',extra=extra)
    assert '/ingresar.jsp' in administrado.pedir('/panel.jsp')[1]
    assert sql(f"SELECT rol_codigo FROM grado.usuario WHERE id={uid};").strip()=='evaluador'
    assert 'Cuenta actualizada' in administrar(uid,'estudiante')
    # Perfil inválido no deja modificaciones parciales ni cambia el rol.
    sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo) SELECT 'Sin perfil','sinperfil@flujo.invalid',contrasena_hash,'estudiante' FROM grado.usuario WHERE id="+str(uid)+';')
    sinperfil=sql("SELECT id FROM grado.usuario WHERE correo='sinperfil@flujo.invalid';").strip()
    assert 'Revisa los datos' in administrar(sinperfil,'director',extra=dict(extra,modalidad=['inexistente']))
    assert sql(f'SELECT count(*) FROM grado.perfil_docente WHERE usuario_id={sinperfil};').strip()=='0'
    print('OK: mensajes privados/lectura, actas/aprobación, pausa, filtros autorizados, cuentas/roles y revocación de sesiones.')
    (RAIZ/'.tools/resultado-pruebas-comunicacion.json').write_text(json.dumps({'resultado':'OK','base':'grado_pruebas'},indent=2),encoding='utf-8')

if __name__=='__main__':
    comprobar()
    ctx=flujo()
    comunicacion(ctx)
    tramites(revisiones(ctx))
    # Tras retirarse o cerrar se conserva la consulta, sin habilitar envíos.
    for nombre in ['alumno','director']:
        c=Cliente()
        c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':ctx['clave']})
        ruta='/mensajes.jsp?id='+ctx['proyecto']
        estado,_,cuerpo,_=c.pedir(ruta)
        assert estado==200 and 'mensaje privado' in cuerpo
        destino=ctx['director'] if nombre=='alumno' else ctx['pareja']
        cantidad=sql('SELECT count(*) FROM grado.mensaje;').strip()
        c.pedir('/acciones/mensaje-enviar.jsp',{'csrf':c.token(ruta),'id':ctx['proyecto'],'destinatario':destino,'contenido':'Fuera de vigencia'})
        assert sql('SELECT count(*) FROM grado.mensaje;').strip()==cantidad
    print('OK: correspondencia histórica conservada y envíos bloqueados tras retiro/cierre.')
