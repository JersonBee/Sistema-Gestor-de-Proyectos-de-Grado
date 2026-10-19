"""Comprueba que el POST pertenezca al proyecto y recorrido mostrado. Solo grado_pruebas."""
import secrets
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

def verificar_contexto():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    prefijo='QA-Contexto-'+secrets.token_hex(6);clave=secrets.token_hex(12)
    cuentas=[];proyectos=[]
    try:
        for rol in ('comite','estudiante'):
            uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES("+literal(prefijo+' '+rol)+','+literal(prefijo.lower()+rol+'@prueba.invalid')+',grado.crear_hash_contrasena('+literal(clave)+'),'+literal(rol)+",'activo') RETURNING id;").splitlines()[0]
            cuentas.append(uid)
        comite,estudiante=cuentas
        for n in (1,2):
            idea=sql(f"INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado) SELECT {estudiante},(SELECT min(id) FROM grado.modalidad),(SELECT min(id) FROM grado.area_experiencia),(SELECT min(id) FROM grado.linea_investigacion),"+literal(prefijo+str(n))+",'Descripción','Objetivos','JSTL','aprobada' RETURNING id;").splitlines()[0]
            pid=sql(f"INSERT INTO grado.proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por) SELECT id,modalidad_id,titulo,objetivos,descripcion,{estudiante} FROM grado.idea WHERE id={idea} RETURNING id;").splitlines()[0]
            proyectos.append(pid)
            sql(f"INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en,finalizada_en,estado) VALUES({pid},'propuesta_1',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'aprobado'),({pid},'propuesta_2',CURRENT_TIMESTAMP,NULL,NULL);")
        a,b=proyectos
        entrega=sql(f"INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) SELECT {b},id,1,{estudiante} FROM grado.proyecto_fase WHERE proyecto_id={b} AND fase_codigo='propuesta_1' RETURNING id;").splitlines()[0]
        ciclo=sql(f'INSERT INTO grado.ciclo_revision(entrega_id,numero) VALUES({entrega},1) RETURNING id;').splitlines()[0]
        revision=sql(f"INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id) VALUES({ciclo},'comite',NULL) RETURNING id;").splitlines()[0]
        solicitud=sql(f"INSERT INTO grado.solicitud(proyecto_id,solicitante_id,tipo,descripcion) VALUES({b},{estudiante},'solicitud','Consulta de contexto') RETURNING id;").splitlines()[0]
        c=Cliente();status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':prefijo.lower()+'comite@prueba.invalid','contrasena':clave})
        assert status==200 and '/panel.jsp' in url
        errores=[]
        def post(accion,datos):
            return c.pedir('/acciones/'+accion+'.jsp',datos|{'csrf':c.token('/proyecto.jsp?id='+a)})[0]
        status=post('solicitud-decidir',{'id':a,'solicitud':solicitud,'decision':'atendida','respuesta':'Respuesta cruzada'})
        if status!=403 or sql(f'SELECT estado FROM grado.solicitud WHERE id={solicitud};').strip()!='pendiente': errores.append('Una solicitud del proyecto B se resolvio desde un POST del proyecto A')
        status=post('revision-decidir',{'id':a,'tipo':'propuesta','revision':revision,'decision':'aprobado','reporte':'Revision cruzada'})
        if status!=403 or sql(f'SELECT decision IS NULL FROM grado.revision_entrega WHERE id={revision};').strip()!='t': errores.append('Una revision del proyecto B se aprobo desde un POST del proyecto A')
        assert not errores,'; '.join(errores)
        status=post('revision-decidir',{'id':b,'tipo':'informe','revision':revision,'decision':'aprobado','reporte':'Recorrido equivocado'})
        assert status==403 and sql(f'SELECT decision IS NULL FROM grado.revision_entrega WHERE id={revision};').strip()=='t','Permitio resolver propuesta como informe'
        assert post('solicitud-decidir',{'id':b,'solicitud':solicitud,'decision':'atendida','respuesta':'Respuesta correcta'})==200
        assert sql(f'SELECT estado FROM grado.solicitud WHERE id={solicitud};').strip()=='atendida'
        assert post('revision-decidir',{'id':b,'tipo':'propuesta','revision':revision,'decision':'aprobado','reporte':'Revision correcta'})==200
        assert sql(f"SELECT decision FROM grado.revision_entrega WHERE id={revision};").strip()=='aprobado'
        print('OK: se rechazan proyectos y recorridos cruzados sin modificar datos; ambas decisiones correctas funcionan.')
    finally:
        if proyectos:
            ids=','.join(proyectos)
            sql(f'''DELETE FROM grado.notificacion WHERE evento_id IN(SELECT id FROM grado.evento_auditoria WHERE proyecto_id IN({ids}));
DELETE FROM grado.evento_auditoria WHERE proyecto_id IN({ids});
DELETE FROM grado.respuesta_solicitud WHERE solicitud_id IN(SELECT id FROM grado.solicitud WHERE proyecto_id IN({ids}));
DELETE FROM grado.solicitud WHERE proyecto_id IN({ids});
DELETE FROM grado.revision_entrega WHERE ciclo_id IN(SELECT c.id FROM grado.ciclo_revision c JOIN grado.entrega_revision e ON e.id=c.entrega_id WHERE e.proyecto_id IN({ids}));
DELETE FROM grado.ciclo_revision WHERE entrega_id IN(SELECT id FROM grado.entrega_revision WHERE proyecto_id IN({ids}));
DELETE FROM grado.entrega_revision WHERE proyecto_id IN({ids});
DELETE FROM grado.proyecto_fase WHERE proyecto_id IN({ids});
DELETE FROM grado.proyecto WHERE id IN({ids});''')
        if cuentas:
            ids=','.join(cuentas)
            sql(f'DELETE FROM grado.idea WHERE autor_id IN({ids}); DELETE FROM grado.sesion_acceso WHERE usuario_id IN({ids}); DELETE FROM grado.usuario WHERE id IN({ids});')

if __name__=='__main__':verificar_contexto()
