"""Bandeja por rol en estados reales de las suites locales."""
def ver_tareas(cliente,textos=(),ausentes=()):
    estado,url,cuerpo,_=cliente.pedir('/tareas.jsp')
    assert estado==200, ('Bandeja no disponible',estado,url,cuerpo[:150])
    for texto in textos: assert texto in cuerpo, ('Falta tarea',texto)
    for texto in ausentes: assert texto not in cuerpo, ('Tarea ajena o no accionable',texto)
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
    print('OK: tareas por rol, revisión, asignación, entrega, actas y mensajes; sin tareas ajenas, pausadas o cerradas.')
