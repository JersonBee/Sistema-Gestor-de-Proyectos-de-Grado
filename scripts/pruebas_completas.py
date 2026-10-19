"""Recorrido completo y matriz de roles. Solo utiliza grado-pruebas local.

Ejecutar: python -u scripts/pruebas_completas.py
Recrea exclusivamente el esquema local de fixtures mediante comprobar().
"""
from pruebas_acceso import comprobar
from pruebas_flujo_inicial import flujo
from pruebas_comunicacion import comunicacion
from pruebas_revisiones import revisiones
from pruebas_final_solicitudes import tramites
from pruebas_permisos_roles import verificar
from pruebas_registro_validacion import verificar_registro
from pruebas_paginacion import verificar_paginacion
from pruebas_sesiones_compartidas import verificar as verificar_sesiones

if __name__=='__main__':
    comprobar()
    contexto=flujo()
    comunicacion(contexto)
    tramites(revisiones(contexto))
    verificar(contexto['clave'])
    verificar_registro()
    verificar_paginacion(contexto['clave'])
    verificar_sesiones()
    print('OK: suite integral y matriz completa de roles finalizadas.')
