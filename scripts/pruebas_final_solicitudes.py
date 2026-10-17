"""Suite integral y trámites/cierre en grado-pruebas. Sin acceso a Supabase."""
import json
from pruebas_acceso import Cliente,RAIZ,comprobar,sql
from pruebas_flujo_inicial import flujo,literal
from pruebas_revisiones import revisiones
from pruebas_resumen import ver_resumen
from pruebas_tareas import ver_tareas

def tramites(ctx):
    clave=ctx['clave']; principal=ctx['proyecto']
    def ingreso(nombre):
        c=Cliente(); estado,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':clave})
        assert estado==200 and '/panel.jsp' in url, ('Ingreso',nombre,url)
        return c
    alumno=ingreso('alumno'); pareja=ingreso('pareja'); comite=ingreso('comite'); director=ingreso('director'); evaluador=ingreso('evaluador'); lectura=ingreso('secretaria'); ajeno=ingreso('ajeno')
    def pagina(nombre,pid): return '/'+nombre+'.jsp?id='+str(pid)
    def post(c,accion,datos,vista,pid):
        estado,url,cuerpo,_=c.pedir('/acciones/'+accion,dict(datos,id=pid,csrf=c.token(pagina(vista,pid))))
        assert estado==200 and '/'+vista+'.jsp' in url, (accion,estado,url,cuerpo[:100])
        return cuerpo
    def pedir(c,pid,tipo='solicitud',preferido='',descripcion='Petición de prueba'):
        return post(c,'solicitud-crear.jsp',{'tipo':tipo,'preferido':preferido,'descripcion':descripcion},'solicitudes',pid)
    def ultima(pid): return sql(f'SELECT id FROM grado.solicitud WHERE proyecto_id={pid} ORDER BY id DESC LIMIT 1;').strip()
    def responder(pid,sid,decision='aprobada',respuesta='Respuesta del Comité'):
        return post(comite,'solicitud-decidir.jsp',{'solicitud':sid,'decision':decision,'respuesta':respuesta},'solicitudes',pid)
    def guardar(c,pid,campo,valor): return post(c,'final-guardar.jsp',{'campo':campo,'valor':valor},'final',pid)
    for vista in ['final','solicitudes','historial']:
        assert alumno.pedir(pagina(vista,principal))[0]==200
        assert lectura.pedir(pagina(vista,principal))[0]==200
        assert ajeno.pedir(pagina(vista,principal))[0]==403
    ver_resumen(alumno,principal,['El Comité puede finalizar','No hay documentos adicionales obligatorios','cancelación por el plazo de 180 días está detenida'])
    ver_tareas(comite,['Revisar el cierre del proyecto'])
    assert 'enlaces deben comenzar' in guardar(alumno,principal,'manual_usuario','javascript:alert(1)')
    assert 'guardado con historial' in guardar(alumno,principal,'manual_usuario','https://documentos.invalid/manual-v1')
    guardar(alumno,principal,'manual_usuario','https://documentos.invalid/manual-v2')
    guardar(pareja,principal,'evidencia_publicacion','https://documentos.invalid/publicacion')
    guardar(alumno,principal,'licencia','Licencia <b>de prueba</b>')
    assert '&lt;b&gt;de prueba&lt;/b&gt;' in alumno.pedir(pagina('final',principal))[2]
    assert 'registra el director' in guardar(alumno,principal,'repositorio','https://documentos.invalid/no-autorizado')
    assert 'guardado con historial' in guardar(director,principal,'repositorio','https://documentos.invalid/repositorio')
    assert sql(f"SELECT count(*) FROM grado.documento_version v JOIN grado.documento d ON d.id=v.documento_id WHERE d.proyecto_id={principal} AND d.tipo_codigo='manual_usuario';").strip()=='2'
    assert alumno.pedir('/acciones/final-cerrar.jsp',{'csrf':alumno.token(pagina('final',principal)),'id':principal})[0]==403
    assert lectura.pedir('/acciones/final-guardar.jsp',{'csrf':lectura.token(pagina('final',principal)),'id':principal,'campo':'licencia','valor':'No'})[0]==403
    # Retiro en pareja: conserva el proyecto y bloquea escrituras del retirado.
    assert 'enviada al Comité' in pedir(alumno,principal,'retiro')
    sid=ultima(principal); responder(principal,sid)
    assert sql(f"SELECT estado FROM grado.proyecto WHERE id={principal};").strip()=='activo'
    assert sql(f'SELECT count(*) FROM grado.participante_proyecto WHERE proyecto_id={principal} AND retiro_en IS NULL;').strip()=='1'
    assert 'participante vigente' in guardar(alumno,principal,'licencia','No autorizado')
    assert alumno.pedir(pagina('historial',principal))[0]==200
    # El Comité puede finalizar sin exigir los adicionales; no deja trámites accionables.
    pedir(pareja,principal,descripcion='Consulta pendiente al momento de cerrar')
    pendiente_cierre=ultima(principal)
    assert 'Proyecto finalizado' in post(comite,'final-cerrar.jsp',{'nota':'Cierre de prueba'},'final',principal)
    ver_resumen(pareja,principal,['El proceso está cerrado','Sin acciones pendientes','no tiene plazos de entrega o revisión activos'],['Vigencia del proyecto hasta:'])
    ver_tareas(comite,ausentes=['Revisar el cierre del proyecto'])
    assert sql(f"SELECT estado='finalizado' AND finalizado_por={ctx['comite']} AND finalizado_en IS NOT NULL FROM grado.proyecto WHERE id={principal};").strip()=='t'
    assert sql(f'SELECT count(*) FROM grado.participante_proyecto WHERE proyecto_id={principal} AND retiro_en IS NULL;').strip()=='0'
    assert sql(f'SELECT estado FROM grado.solicitud WHERE id={pendiente_cierre};').strip()=='atendida'
    assert sql(f"SELECT EXISTS(SELECT 1 FROM grado.proyecto x WHERE x.idea_id=p.idea_id AND x.estado<>'cancelado') FROM grado.proyecto p WHERE p.id={principal};").strip()=='t', 'Liberó idea de proyecto finalizado'
    assert director.pedir(pagina('final',principal))[0]==200
    cantidad=sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='finalizar_proyecto';").strip()
    post(comite,'final-cerrar.jsp',{},'final',principal)
    assert sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='finalizar_proyecto';").strip()==cantidad
    # Cambio de director durante su revisión pendiente.
    pid=sql("SELECT id FROM grado.proyecto WHERE titulo='demora';").strip(); estudiante=ingreso('demora')
    def docente_nuevo(nombre,rol,modelo):
        uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo) SELECT "+literal(nombre)+','+literal(nombre+'@flujo.invalid')+",contrasena_hash,"+literal(rol)+f' FROM grado.usuario WHERE id={modelo} RETURNING id;').splitlines()[0]
        sql(f'INSERT INTO grado.perfil_docente SELECT {uid},cursos,titulos_academicos,temas_preferencia FROM grado.perfil_docente WHERE usuario_id={modelo}; '
            f'INSERT INTO grado.docente_area SELECT {uid},area_id FROM grado.docente_area WHERE docente_id={modelo}; '
            f'INSERT INTO grado.docente_linea SELECT {uid},linea_id FROM grado.docente_linea WHERE docente_id={modelo}; '
            f'INSERT INTO grado.docente_modalidad SELECT {uid},modalidad_id FROM grado.docente_modalidad WHERE docente_id={modelo};')
        return uid,ingreso(nombre)
    nuevo_director,docente=docente_nuevo('director-nuevo','director',ctx['director'])
    nuevo_evaluador,eval_nuevo=docente_nuevo('evaluador-nuevo','evaluador',ctx['evaluador'])
    seguimiento='/seguimiento.jsp?id='+pid+'&tipo=propuesta'
    def envio():
        estado,url,html,_=estudiante.pedir('/acciones/documentos-enviar.jsp',{'csrf':estudiante.token(seguimiento),'id':pid,'tipo':'propuesta','f_dc_124':'https://documentos.invalid/p','turnitin':'https://documentos.invalid/t'})
        assert estado==200 and 'Conjunto enviado al director' in html, ('Envío de prueba',url)
    envio()
    def revision(): return sql(f'SELECT r.id FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id WHERE e.proyecto_id={pid} AND r.decision IS NULL AND c.finalizado_en IS NULL;').strip()
    def aprobar(c):
        estado,url,html,_=c.pedir('/acciones/revision-decidir.jsp',{'csrf':c.token(seguimiento),'id':pid,'tipo':'propuesta','revision':revision(),'decision':'aprobado','reporte':'Revisión de prueba'})
        assert estado==200, url
        return html
    antes=sql('SELECT count(*) FROM grado.solicitud;').strip()
    pedir(estudiante,pid,'cambio_director',ctx['evaluador'])
    assert sql('SELECT count(*) FROM grado.solicitud;').strip()==antes, 'Aceptó un evaluador como director'
    assert 'enviada al Comité' in pedir(estudiante,pid,'cambio_director',nuevo_director)
    cambio=ultima(pid); rev=revision()
    assert estudiante.pedir('/acciones/solicitud-decidir.jsp',{'csrf':estudiante.token(pagina('solicitudes',pid)),'id':pid,'solicitud':cambio,'decision':'aprobada','respuesta':'No'})[0]==403
    post(comite,'proyecto-pausa.jsp',{'operacion':'pausar','motivo':'Pausa de trámite'},'proyecto',pid)
    responder(pid,cambio)
    assert sql(f'SELECT estado FROM grado.solicitud WHERE id={cambio};').strip()=='pendiente'
    post(comite,'proyecto-pausa.jsp',{'operacion':'reanudar'},'proyecto',pid)
    assert 'cambios aplicados' in responder(pid,cambio)
    assert sql(f'SELECT responsable_id={nuevo_director} AND limite_en=grado.limite_dias_calendario(asignada_en,5) FROM grado.revision_entrega WHERE id={rev};').strip()=='t'
    assert 'no está disponible' in aprobar(director)
    assert 'pasó al evaluador' in aprobar(docente)
    pedir(estudiante,pid,'cambio_evaluador',nuevo_evaluador); responder(pid,ultima(pid))
    assert 'no está disponible' in aprobar(evaluador)
    assert 'pasó al Comité' in aprobar(eval_nuevo)
    # Quejas generales, respuesta escapada y retiro del último integrante.
    pedir(estudiante,pid,'queja',descripcion='Consulta <b>de prueba</b>'); queja=ultima(pid)
    responder(pid,queja,'atendida','Respuesta <b>registrada</b>')
    assert '&lt;b&gt;registrada&lt;/b&gt;' in estudiante.pedir(pagina('solicitudes',pid))[2]
    pedir(estudiante,pid,descripcion='Pendiente cuando se cancela'); solicitud=ultima(pid)
    pedir(estudiante,pid,'retiro'); retiro=ultima(pid); responder(pid,retiro)
    assert sql(f'SELECT estado FROM grado.proyecto WHERE id={pid};').strip()=='cancelado'
    assert sql(f'SELECT estado FROM grado.solicitud WHERE id={solicitud};').strip()=='atendida'
    assert sql(f"SELECT NOT EXISTS(SELECT 1 FROM grado.proyecto x WHERE x.idea_id=p.idea_id AND x.estado<>'cancelado') FROM grado.proyecto p WHERE p.id={pid};").strip()=='t'
    assert 'proyecto fue cancelado' in estudiante.pedir(pagina('solicitudes',pid))[2]
    assert docente.pedir(pagina('historial',pid))[0]==200
    assert sql(f'SELECT count(*) FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id WHERE e.proyecto_id={pid} AND r.decision IS NULL;').strip()=='0'
    # Cierre de un proyecto sin ningún adicional registrado, mediante fixture aislado.
    sql((RAIZ/'database/pruebas/final_opcional.sql').read_text(encoding='utf-8'))
    print('OK: entregables opcionales, versiones, repositorio por director, cierre exclusivo del Comité, cambio de docentes con revisión pendiente, retiro en pareja/individual, pausas, cierre de trámites e historial autorizado.')
    (RAIZ/'.tools/resultado-pruebas-final.json').write_text(json.dumps({'resultado':'OK','base':'grado_pruebas'},indent=2),encoding='utf-8')

if __name__=='__main__':
    comprobar()
    tramites(revisiones(flujo()))
