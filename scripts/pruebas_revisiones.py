"""Revisiones y plazos con relojes controlados en PostgreSQL local aislado."""
import json
from pruebas_acceso import Cliente,RAIZ,comprobar,sql
from pruebas_flujo_inicial import flujo,literal
from pruebas_resumen import ver_resumen
from pruebas_tareas import ver_tareas

def revisiones(ctx):
    proyecto=ctx['proyecto']; clave=ctx['clave']
    def ingreso(nombre):
        c=Cliente(); estado,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':nombre+'@flujo.invalid','contrasena':clave})
        assert estado==200 and '/panel.jsp' in url
        return c
    alumno=ingreso('alumno'); director=ingreso('director'); evaluador=ingreso('evaluador'); comite=ingreso('comite'); ajeno=ingreso('ajeno')
    def ruta(tipo='propuesta',pid=proyecto): return '/seguimiento.jsp?id='+str(pid)+'&tipo='+tipo
    def post(c,accion,datos,pagina):
        estado,url,cuerpo,_=c.pedir('/acciones/'+accion,dict(datos,csrf=c.token(pagina)))
        assert estado==200 and '/seguimiento.jsp' in url or estado==200 and '/proyecto.jsp' in url, (accion,estado,url,cuerpo[:120])
        return cuerpo
    def pendiente(pid=proyecto):
        return sql(f"SELECT r.id FROM grado.revision_entrega r JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id WHERE e.proyecto_id={pid} AND c.finalizado_en IS NULL AND r.decision IS NULL ORDER BY r.id DESC LIMIT 1;").strip()
    def decidir(c,decision='aprobado',tipo='propuesta',pid=proyecto,reporte='Revisión correcta'):
        return post(c,'revision-decidir.jsp',{'id':pid,'tipo':tipo,'revision':pendiente(pid),'decision':decision,'reporte':reporte},ruta(tipo,pid))
    def enviar(tipo='propuesta',c=alumno,pid=proyecto):
        datos={'id':pid,'tipo':tipo,'turnitin':'https://documentos.invalid/turnitin','adicionales':'https://documentos.invalid/anexo\r\n\r\nhttps://documentos.invalid/segundo-anexo\r\n'}
        if tipo=='propuesta': datos['f_dc_124']='https://documentos.invalid/propuesta'
        else: datos|={'f_dc_125':'https://documentos.invalid/informe','f_dc_129':'https://documentos.invalid/evaluacion'}
        return post(c,'documentos-enviar.jsp',datos,ruta(tipo,pid))
    assert alumno.pedir(ruta())[0]==200 and alumno.pedir(ruta('informe'))[0]==200
    assert ajeno.pedir(ruta())[0]==403
    assert ajeno.pedir('/resumen.jsp?id='+str(proyecto))[0]==403
    ver_resumen(alumno,proyecto,['Presentar el conjunto completo al director','F-DC-124 y reporte Turnitin'])
    # No debe crear entregas si faltan documentos o se cambia el tipo de recorrido.
    antes=sql('SELECT count(*) FROM grado.entrega_revision;').strip()
    post(alumno,'documentos-enviar.jsp',{'id':proyecto,'tipo':'propuesta','f_dc_124':'https://documentos.invalid/p'},ruta())
    assert sql('SELECT count(*) FROM grado.entrega_revision;').strip()==antes
    assert 'Conjunto enviado al director' in enviar()
    assert sql(f"SELECT string_agg(v.url, ',' ORDER BY v.url) FROM grado.documento_version v JOIN grado.documento d ON d.id=v.documento_id WHERE d.proyecto_id={proyecto} AND d.tipo_codigo='adicional' AND d.proyecto_fase_id=(SELECT id FROM grado.proyecto_fase WHERE proyecto_id={proyecto} AND fase_codigo='propuesta_1');").strip()=='https://documentos.invalid/anexo,https://documentos.invalid/segundo-anexo', 'CRLF altero o perdio enlaces adicionales de propuesta'
    ver_resumen(alumno,proyecto,['Revisar el conjunto completo','director','Revisión hasta:','El conjunto está entregado'])
    ver_tareas(director,['Revisar el conjunto · Propuesta I','Revisión hasta'])
    ver_tareas(alumno,ausentes=['Presentar el conjunto · Propuesta I'])
    ver_tareas(evaluador,ausentes=['Revisar el conjunto · Propuesta I'])
    rev=pendiente()
    assert sql(f"SELECT limite_en=grado.limite_dias_calendario(asignada_en,5) FROM grado.revision_entrega WHERE id={rev};").strip()=='t'
    assert 'no está disponible' in decidir(evaluador), 'Permitió omitir al director'
    assert 'escribe el reporte' in decidir(director,reporte=''), 'Aceptó aprobación sin reporte'
    assert 'pasó al evaluador' in decidir(director)
    ver_tareas(evaluador,['Revisar el conjunto · Propuesta II'])
    assert 'ciclo reinicia con el director' in decidir(evaluador,'rechazado',reporte='Corrige <b>los objetivos</b>')
    ver_resumen(alumno,proyecto,['Corregir y reenviar el conjunto completo','Corrección hasta:'],['Revisión hasta:'])
    ver_tareas(alumno,['Presentar el conjunto · Propuesta I'])
    assert '&lt;b&gt;los objetivos&lt;/b&gt;' in alumno.pedir(ruta())[2]
    assert sql(f"SELECT fase_codigo FROM grado.proyecto_fase WHERE proyecto_id={proyecto} AND finalizada_en IS NULL AND iniciada_en IS NOT NULL;").strip()=='propuesta_1'
    # Tres días: alerta una sola vez; después sigue admitiendo el reenvío completo.
    cor=sql(f"SELECT pc.id FROM grado.plazo_correccion pc JOIN grado.revision_entrega r ON r.id=pc.revision_id JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id WHERE e.proyecto_id={proyecto} AND pc.entrega_reenvio_id IS NULL ORDER BY pc.id DESC LIMIT 1;").strip()
    sql(f"SELECT grado.procesar_plazos((SELECT limite_en-interval '1 second' FROM grado.plazo_correccion WHERE id={cor}));")
    assert sql(f'SELECT alertada_en IS NULL FROM grado.plazo_correccion WHERE id={cor};').strip()=='t'
    sql(f'SELECT grado.procesar_plazos((SELECT limite_en FROM grado.plazo_correccion WHERE id={cor}));')
    cantidad=sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='alertar_correccion';").strip()
    sql(f'SELECT grado.procesar_plazos((SELECT limite_en FROM grado.plazo_correccion WHERE id={cor}));')
    assert sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='alertar_correccion';").strip()==cantidad
    assert 'Conjunto enviado al director' in enviar()
    assert sql(f'SELECT entrega_reenvio_id IS NOT NULL FROM grado.plazo_correccion WHERE id={cor};').strip()=='t'
    assert 'pasó al evaluador' in decidir(director)
    assert 'pasó al Comité' in decidir(evaluador)
    ver_resumen(comite,proyecto,['Comité','no tiene un plazo automático'],['Revisión hasta:'])
    rev_comite=pendiente()
    assert sql(f'SELECT limite_en IS NULL AND responsable_id IS NULL FROM grado.revision_entrega WHERE id={rev_comite};').strip()=='t', 'Impuso plazo o responsable arbitrario al Comité'
    assert 'ciclo reinicia con el director' in decidir(comite,'rechazado')
    assert 'Conjunto enviado al director' in enviar()
    decidir(director); decidir(evaluador)
    assert 'Comenzó Informe I' in decidir(comite)
    ver_resumen(alumno,proyecto,['Esperar la habilitación de Informe I','F-DC-125, F-DC-129 y reporte Turnitin','Vigencia del proyecto hasta:'])
    ver_tareas(alumno,ausentes=['Presentar el conjunto · Informe I'])
    assert sql(f"SELECT inicio_vigencia_en IS NOT NULL AND informe_habilitado_en=grado.habilitacion_informe(inicio_vigencia_en) AND vence_en=grado.limite_dias_calendario(inicio_vigencia_en,180) FROM grado.proyecto WHERE id={proyecto};").strip()=='t'
    assert '90 días' in enviar('informe'), 'Permitió entregar informe antes de 90 días'
    sql(f"SELECT grado.procesar_plazos((SELECT informe_habilitado_en-interval '1 second' FROM grado.proyecto WHERE id={proyecto}));")
    assert sql(f'SELECT aviso_informe_habilitado_en IS NULL FROM grado.proyecto WHERE id={proyecto};').strip()=='t'
    sql(f'SELECT grado.procesar_plazos((SELECT informe_habilitado_en FROM grado.proyecto WHERE id={proyecto}));')
    cantidad=sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='habilitar_informe';").strip()
    sql(f'SELECT grado.procesar_plazos((SELECT informe_habilitado_en FROM grado.proyecto WHERE id={proyecto}));')
    assert sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='habilitar_informe';").strip()==cantidad
    # Cambiar solamente el reloj de este proyecto de prueba para atravesar la espera.
    sql(f"UPDATE grado.proyecto SET inicio_vigencia_en=CURRENT_TIMESTAMP-interval '95 days',informe_habilitado_en=grado.habilitacion_informe(CURRENT_TIMESTAMP-interval '95 days'),vence_en=grado.limite_dias_calendario(CURRENT_TIMESTAMP-interval '95 days',180) WHERE id={proyecto};")
    assert 'Conjunto enviado al director' in enviar('informe')
    version=sql(f"SELECT max(v.id) FROM grado.documento_version v JOIN grado.documento d ON d.id=v.documento_id WHERE d.proyecto_id={proyecto};").strip()
    estado,_,html,_=alumno.pedir('/documento.jsp?version='+version)
    assert estado==200 and '<iframe' in html and 'frame-src https: http:' in html, 'No renderizó previsualización'
    assert ajeno.pedir('/documento.jsp?version='+version)[0]==403
    decidir(director,tipo='informe'); decidir(evaluador,tipo='informe')
    assert 'avanzó a la fase Final' in decidir(comite,tipo='informe')
    sql(f"SELECT grado.procesar_plazos((SELECT vence_en+interval '1 day' FROM grado.proyecto WHERE id={proyecto}));")
    assert sql(f"SELECT estado='activo' AND informe_aprobado_comite_en IS NOT NULL FROM grado.proyecto WHERE id={proyecto};").strip()=='t', 'Canceló informe aprobado por el Comité'
    # Preparar proyectos adicionales a través de las mismas funciones con tokens locales.
    token_comite=sql('SELECT token FROM grado.iniciar_sesion('+literal('comite@flujo.invalid')+','+literal(clave)+');').strip()
    def nuevo(nombre):
        usuario=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo) SELECT "+literal(nombre)+','+literal(nombre+'@flujo.invalid')+",contrasena_hash,'estudiante' FROM grado.usuario WHERE correo='alumno@flujo.invalid' RETURNING id;").splitlines()[0]
        token=sql('SELECT token FROM grado.iniciar_sesion('+literal(nombre+'@flujo.invalid')+','+literal(clave)+');').strip()
        idea=sql(f"INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado) SELECT {usuario},modalidad_id,area_id,linea_id,{literal(nombre)},descripcion,objetivos,tecnologias,'aprobada' FROM grado.idea ORDER BY id LIMIT 1 RETURNING id;").splitlines()[0]
        pid=sql('SELECT recurso_id FROM grado.crear_proyecto('+literal(token)+','+idea+','+literal(json.dumps({'nombre':nombre}))+');').strip()
        sql('SELECT * FROM grado.presentar_pago('+literal(token)+','+pid+",'https://documentos.invalid/pago','');")
        entrega=sql('SELECT id FROM grado.entrega_revision WHERE proyecto_id='+pid+';').strip()
        sql('SELECT * FROM grado.decidir_pago('+literal(token_comite)+','+pid+','+entrega+",'aprobado','Correcto');")
        sql('SELECT * FROM grado.asignar_docentes('+literal(token_comite)+','+pid+','+ctx['director']+','+ctx['evaluador']+');')
        return pid,token,ingreso(nombre)
    demorado,_,estudiante_demora=nuevo('demora')
    enviar(c=estudiante_demora,pid=demorado)
    rev_demora=pendiente(demorado)
    sql(f"SELECT grado.procesar_plazos((SELECT limite_en-interval '1 second' FROM grado.revision_entrega WHERE id={rev_demora}));")
    assert pendiente(demorado)==rev_demora
    sql(f'SELECT grado.procesar_plazos((SELECT limite_en FROM grado.revision_entrega WHERE id={rev_demora}));')
    assert sql(f"SELECT decision FROM grado.revision_entrega WHERE id={rev_demora};").strip()=='aplicado'
    assert pendiente(demorado)=='', 'Avanzó automáticamente al evaluador'
    assert 'Conjunto enviado al director' in enviar(c=estudiante_demora,pid=demorado), 'No permitió reutilizar enlaces tras vencimiento'
    decidir(director,pid=demorado)
    rev_eval=pendiente(demorado)
    sql(f'SELECT grado.procesar_plazos((SELECT limite_en FROM grado.revision_entrega WHERE id={rev_eval}));')
    assert sql(f"SELECT decision FROM grado.revision_entrega WHERE id={rev_eval};").strip()=='aplicado'
    assert sql(f"SELECT fase_codigo FROM grado.proyecto_fase WHERE proyecto_id={demorado} AND finalizada_en IS NULL AND iniciada_en IS NOT NULL;").strip()=='propuesta_1'
    # Pausa durante revisión: no se acepta decidir y Cron no vence la revisión.
    pausado,_,estudiante_pausa=nuevo('pausado')
    enviar(c=estudiante_pausa,pid=pausado); rev_pausa=pendiente(pausado)
    proyecto_url='/proyecto.jsp?id='+pausado
    assert 'Proyecto pausado' in post(comite,'proyecto-pausa.jsp',{'id':pausado,'operacion':'pausar','motivo':'Receso autorizado'},proyecto_url)
    assert 'no está disponible' in decidir(director,pid=pausado)
    sql(f"SELECT grado.procesar_plazos((SELECT limite_en+interval '10 days' FROM grado.revision_entrega WHERE id={rev_pausa}));")
    assert pendiente(pausado)==rev_pausa
    limite_antes=sql(f'SELECT limite_en FROM grado.revision_entrega WHERE id={rev_pausa};').strip()
    assert 'Proyecto reanudado' in post(comite,'proyecto-pausa.jsp',{'id':pausado,'operacion':'reanudar'},proyecto_url)
    assert sql(f"SELECT limite_en>{literal(limite_antes)}::timestamptz AND to_char(limite_en AT TIME ZONE 'America/Bogota','HH24:MI')='23:59' FROM grado.revision_entrega WHERE id={rev_pausa};").strip()=='t'
    # Vigencia: cancelación exactamente al límite, liberación de idea/participantes.
    vencido,_,estudiante_vencimiento=nuevo('vencido')
    enviar(c=estudiante_vencimiento,pid=vencido); decidir(director,pid=vencido); decidir(evaluador,pid=vencido); decidir(comite,pid=vencido)
    sql(f"SELECT grado.procesar_plazos((SELECT vence_en-interval '1 second' FROM grado.proyecto WHERE id={vencido}));")
    assert sql(f'SELECT estado FROM grado.proyecto WHERE id={vencido};').strip()=='activo'
    sql(f'SELECT grado.procesar_plazos((SELECT vence_en FROM grado.proyecto WHERE id={vencido}));')
    assert sql(f'SELECT estado FROM grado.proyecto WHERE id={vencido};').strip()=='cancelado'
    assert sql(f'SELECT count(*) FROM grado.participante_proyecto WHERE proyecto_id={vencido} AND retiro_en IS NULL;').strip()=='0'
    assert sql(f"SELECT NOT EXISTS(SELECT 1 FROM grado.proyecto x WHERE x.idea_id=p.idea_id AND x.estado<>'cancelado') FROM grado.proyecto p WHERE p.id={vencido};").strip()=='t'
    assert director.pedir('/proyecto.jsp?id='+vencido)[0]==200, 'Perdió lectura histórica tras cancelación'
    cantidad=sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='cancelar_por_vencimiento';").strip()
    sql(f'SELECT grado.procesar_plazos((SELECT vence_en FROM grado.proyecto WHERE id={vencido}));')
    assert sql("SELECT count(*) FROM grado.evento_auditoria WHERE accion='cancelar_por_vencimiento';").strip()==cantidad
    assert alumno.pedir('/avisos.jsp')[0]==200
    ajeno_id=sql("SELECT id FROM grado.notificacion WHERE destinatario_id="+ctx['director']+' ORDER BY id DESC LIMIT 1;').strip()
    alumno.pedir('/acciones/aviso-leer.jsp',{'csrf':alumno.token('/avisos.jsp'),'id':ajeno_id})
    assert sql('SELECT leido_en IS NULL FROM grado.notificacion WHERE id='+ajeno_id+';').strip()=='t', 'Marcó avisos de otro usuario'
    propio=sql('SELECT id FROM grado.notificacion WHERE destinatario_id='+ctx['alumno']+' ORDER BY id DESC LIMIT 1;').strip()
    alumno.pedir('/acciones/aviso-leer.jsp',{'csrf':alumno.token('/avisos.jsp'),'id':propio})
    assert sql('SELECT leido_en IS NOT NULL FROM grado.notificacion WHERE id='+propio+';').strip()=='t'
    sql((RAIZ/'database/pruebas/pausa_calendario.sql').read_text(encoding='utf-8'))
    print('OK: flujo director/evaluador/Comité, reinicio por rechazo, conjunto versionado, previsualización autorizada, alertas 3/5 días, espera 90, vigencia 180, pausas, historial y avisos privados.')
    (RAIZ/'.tools/resultado-pruebas-revisiones.json').write_text(json.dumps({'resultado':'OK','base':'grado_pruebas'},indent=2),encoding='utf-8')
    return ctx

if __name__=='__main__':
    comprobar()
    revisiones(flujo())
