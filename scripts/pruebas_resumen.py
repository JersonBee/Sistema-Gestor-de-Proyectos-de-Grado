"""Resumen del proyecto sobre estados reales del flujo, en grado-pruebas."""
def ver_resumen(cliente,proyecto,textos=(),ausentes=()):
    estado,url,cuerpo,_=cliente.pedir('/resumen.jsp?id='+str(proyecto))
    assert estado==200, ('Resumen no disponible',estado,url,cuerpo[:150])
    for texto in textos:
        assert texto in cuerpo, ('Falta información del resumen',texto)
    for texto in ausentes:
        assert texto not in cuerpo, ('Información incorrecta en resumen',texto)
    return cuerpo

if __name__=='__main__':
    from pruebas_acceso import comprobar
    from pruebas_flujo_inicial import flujo
    from pruebas_comunicacion import comunicacion
    from pruebas_revisiones import revisiones
    from pruebas_final_solicitudes import tramites
    comprobar()
    ctx=flujo()
    comunicacion(ctx)
    tramites(revisiones(ctx))
    print('OK: resumen de Pago, revisión, corrección, espera, pausa, Final y cierre, con acceso autorizado.')
