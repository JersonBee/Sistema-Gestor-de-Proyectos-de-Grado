"""Un proyecto cerrado no debe anunciar que puede reenviarse una corrección."""
import json
import secrets
from pruebas_acceso import Cliente, sql
from pruebas_flujo_inicial import literal


def verificar_correccion_cerrada():
    assert sql('SELECT current_database();').strip() == 'grado_pruebas'
    fila = json.loads(sql("""SELECT row_to_json(q) FROM (
 SELECT pc.id,pc.entrega_reenvio_id,p.id AS proyecto_id,
 CASE WHEN f.fase_codigo='propuesta_1' THEN 'propuesta' ELSE 'informe' END AS tipo
 FROM grado.plazo_correccion pc JOIN grado.revision_entrega r ON r.id=pc.revision_id
 JOIN grado.ciclo_revision c ON c.id=r.ciclo_id JOIN grado.entrega_revision e ON e.id=c.entrega_id
 JOIN grado.proyecto p ON p.id=e.proyecto_id JOIN grado.proyecto_fase f ON f.id=e.fase_origen_id
 WHERE p.estado IN('cancelado','finalizado') AND f.fase_codigo IN('propuesta_1','informe_1')
 ORDER BY pc.id LIMIT 1) q;""").strip())
    assert fila, 'Ejecutar después de los flujos locales de revisión y cierre'
    clave = secrets.token_hex(12)
    correo = 'qa-correccion-'+secrets.token_hex(6)+'@prueba.invalid'
    uid = sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES('QA consulta de corrección',"+literal(correo)+',grado.crear_hash_contrasena('+literal(clave)+"),'secretaria','activo') RETURNING id;").splitlines()[0]
    try:
        # Simula un cierre con una corrección sin reenviar. Se restaura en finally.
        sql(f"UPDATE grado.plazo_correccion SET entrega_reenvio_id=NULL WHERE id={fila['id']};")
        c = Cliente()
        status,url,_,_ = c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and '/panel.jsp' in url
        status,_,body,_ = c.pedir('/seguimiento.jsp?id='+str(fila['proyecto_id'])+'&tipo='+fila['tipo'])
        assert status==200
        assert 'Puedes consultar su historial' in body
        assert 'Plazo de corrección registrado' in body and 'referencia histórica' in body
        assert 'Si se supera, recibirás una alerta y podrás reenviar' not in body, 'Un proyecto cerrado anuncia reenvíos y alertas de corrección activas'
        assert '/acciones/documentos-enviar.jsp' not in body
        print('OK: corrección pendiente conservada como historial sin prometer alertas ni reenvíos en proyecto cerrado.')
    finally:
        anterior = 'NULL' if fila['entrega_reenvio_id'] is None else str(fila['entrega_reenvio_id'])
        sql(f"UPDATE grado.plazo_correccion SET entrega_reenvio_id={anterior} WHERE id={fila['id']}; DELETE FROM grado.sesion_acceso WHERE usuario_id={uid}; DELETE FROM grado.usuario WHERE id={uid};")


if __name__ == '__main__':
    verificar_correccion_cerrada()
