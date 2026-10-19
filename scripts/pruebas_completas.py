"""Recorrido completo y matriz de roles. Solo utiliza grado-pruebas local.

Ejecutar: python -u scripts/pruebas_completas.py
Recrea exclusivamente el esquema local de fixtures mediante comprobar().
"""
from pruebas_acceso import comprobar
from pruebas_textos_comunicacion import verificar_textos_comunicacion
from pruebas_textos_tramites import verificar_textos_tramites
from pruebas_espacios_ideas import verificar_espacios_ideas
from pruebas_limites_acceso import verificar_limites_acceso
from pruebas_pago_historico import verificar_pago_historico
from pruebas_documentos_fases import verificar_documentos_fases
from pruebas_correccion_proyecto_cerrado import verificar_correccion_cerrada
from pruebas_flujo_inicial import flujo
from pruebas_comunicacion import comunicacion
from pruebas_revisiones import revisiones
from pruebas_final_solicitudes import tramites
from pruebas_permisos_roles import verificar
from pruebas_registro_validacion import verificar_registro
from pruebas_paginacion import verificar_paginacion
from pruebas_paginacion_empates import verificar_empates
from pruebas_contexto_acciones import verificar_contexto
from pruebas_espacios_administracion import verificar_espacios_administracion
from pruebas_sesiones_compartidas import verificar as verificar_sesiones

if __name__=='__main__':
    comprobar()
    verificar_limites_acceso()
    contexto=flujo()
    comunicacion(contexto)
    tramites(revisiones(contexto))
    verificar_pago_historico()
    verificar_documentos_fases()
    verificar_correccion_cerrada()
    verificar(contexto['clave'])
    verificar_registro()
    verificar_espacios_administracion()
    verificar_espacios_ideas()
    verificar_textos_tramites()
    verificar_textos_comunicacion()
    verificar_paginacion(contexto['clave'])
    verificar_empates()
    verificar_contexto()
    verificar_sesiones()
    print('OK: suite integral y matriz completa de roles finalizadas.')
