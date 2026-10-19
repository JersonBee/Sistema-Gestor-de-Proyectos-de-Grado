"""Consulta histórica de los datos de Pago tras retiro/cierre. Solo grado_pruebas."""
import html,json,secrets
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

def verificar_pago_historico():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    filas=json.loads(sql("""SELECT coalesce(json_agg(row_to_json(q)),'[]'::json) FROM (
SELECT p.id,p.estado,pp.nombre_en_pago,pp.correo_en_pago,pp.documento_en_pago,pp.telefono_en_pago,pp.retiro_en
FROM grado.proyecto p JOIN grado.participante_proyecto pp ON pp.proyecto_id=p.id
WHERE p.id IN(SELECT DISTINCT ON(p2.estado) p2.id FROM grado.proyecto p2 WHERE p2.estado IN('activo','cancelado','finalizado') AND EXISTS(SELECT 1 FROM grado.participante_proyecto pp2 WHERE pp2.proyecto_id=p2.id) AND EXISTS(SELECT 1 FROM grado.datos_pago dp WHERE dp.proyecto_id=p2.id) ORDER BY p2.estado,p2.id)
ORDER BY p.id,pp.plaza,pp.id) q;""").strip())
    assert {f['estado'] for f in filas}=={'activo','cancelado','finalizado'},'Ejecutar después de los flujos locales de cierre y retiro'
    prefijo='QA-PagoHistorico-'+secrets.token_hex(6);clave=secrets.token_hex(12);correo=prefijo.lower()+'@prueba.invalid'
    uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES("+literal(prefijo)+','+literal(correo)+',grado.crear_hash_contrasena('+literal(clave)+"),'secretaria','activo') RETURNING id;").splitlines()[0]
    try:
        c=Cliente();status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and '/panel.jsp' in url
        for pid in sorted({f['id'] for f in filas}):
            status,_,body,_=c.pedir('/pago.jsp?id='+str(pid));assert status==200
            equipo=html.unescape(body.split('<h2>Participantes presentados</h2>',1)[1].split('</section>',1)[0])
            for f in [x for x in filas if x['id']==pid]:
                for campo in ('nombre_en_pago','correo_en_pago','documento_en_pago','telefono_en_pago'):
                    if f[campo]:assert f[campo] in equipo, 'Pago oculta '+campo+' de un participante historico en proyecto '+str(pid)
                if f['retiro_en']:assert 'Participación cerrada' in equipo,'No diferencia participación histórica de vigente'
            assert '/acciones/pago-enviar.jsp' not in body and '/acciones/pago-decidir.jsp' not in body,'Secretaría recibió formularios de escritura'
        print('OK: Pago conserva nombre, correo, documento y teléfono en proyectos activos, cancelados y finalizados; Secretaría solo consulta.')
    finally:
        sql(f'DELETE FROM grado.sesion_acceso WHERE usuario_id={uid}; DELETE FROM grado.usuario WHERE id={uid};')

if __name__=='__main__':verificar_pago_historico()
