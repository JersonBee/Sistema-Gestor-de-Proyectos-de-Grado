"""Genera fuentes Graphviz del MER desde metadatos, sin credenciales ni datos personales."""
from collections import defaultdict
from html import escape
import json
from pathlib import Path
import re

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / 'docs/diagramas'
meta = json.loads((SALIDA / 'esquema_mer.json').read_text(encoding='utf-8'))
tablas = defaultdict(list)
for columna in meta['columnas']:
    tablas[columna['table_name']].append(columna)
primarias = defaultdict(set)
unicas = defaultdict(list)
for r in meta['restricciones']:
    if r['contype'] in ('p', 'u'):
        campos = set(re.search(r'\(([^)]+)\)', r['definicion']).group(1).split(', '))
        unicas[r['tabla']].append(campos)
        if r['contype'] == 'p':
            primarias[r['tabla']] = campos
relaciones = []
for r in meta['restricciones']:
    if r['contype'] == 'f':
        m = re.search(r'FOREIGN KEY \(([^)]+)\) REFERENCES (?:grado\.)?(\w+)\(([^)]+)\)', r['definicion'])
        assert m, r
        relaciones.append((r['tabla'], m[2], m[1].split(', '), m[3].split(', ')))
foraneas = defaultdict(set)
for hijo, padre, columnas, referidas in relaciones:
    foraneas[hijo].update(columnas)

grupos = {
    'Cuentas y aptitud docente': ('#176B4A', ['rol','usuario','perfil_docente','area_experiencia','docente_area','modalidad','docente_modalidad','linea_investigacion','docente_linea']),
    'Ideas y conformación': ('#427357', ['idea','decision_idea','proyecto','participante_proyecto','asignacion_proyecto','pausa_proyecto','datos_pago']),
    'Fases y evaluación': ('#3B617A', ['fase','proyecto_fase','entrega_revision','ciclo_revision','revision_entrega','plazo_correccion']),
    'Documentos y cierre': ('#6A6080', ['tipo_documento','documento','documento_version','entrega_documento_version','entrega_final']),
    'Trámites y comunicación': ('#866332', ['solicitud','respuesta_solicitud','acta','acta_proyecto','mensaje','evento_auditoria','notificacion']),
    'Sesiones y control de acceso': ('#52616B', ['sesion_acceso','intento_acceso','sesion_http']),
}
assert {t for _, lista in grupos.values() for t in lista} == set(tablas)
colores = {t: color for color, lista in grupos.values() for t in lista}


def etiqueta(tabla, completo):
    filas = [f'<TR><TD COLSPAN="3" BGCOLOR="{colores[tabla]}" CELLPADDING="10"><FONT COLOR="white" POINT-SIZE="15"><B>{escape(tabla)}</B></FONT></TD></TR>']
    for c in tablas[tabla]:
        campo = c['column_name']
        if not completo and campo not in primarias[tabla] | foraneas[tabla] | {'estado','rol_codigo','numero','titulo'}:
            continue
        claves = (('PK ' if campo in primarias[tabla] else '') + ('FK' if campo in foraneas[tabla] else '')) or '&#160;'
        tipo = {'timestamp with time zone':'timestamptz','character varying':'varchar','character':'char'}.get(c['data_type'],c['data_type'])
        nota = ' · NULL' if c['is_nullable']=='YES' else ''
        filas.append(f'<TR><TD ALIGN="LEFT"><FONT COLOR="#176B4A"><B>{claves}</B></FONT></TD><TD ALIGN="LEFT" PORT="{campo}">{escape(campo)}</TD><TD ALIGN="LEFT"><FONT COLOR="#65717C">{escape(tipo+nota)}</FONT></TD></TR>')
    return '<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="5" BGCOLOR="#F4F7F5">'+''.join(filas)+'</TABLE>'


resumen = {'usuario','perfil_docente','idea','proyecto','participante_proyecto','asignacion_proyecto','proyecto_fase','documento','documento_version','entrega_revision','entrega_documento_version','ciclo_revision','revision_entrega','solicitud','respuesta_solicitud','acta','acta_proyecto','evento_auditoria','notificacion','mensaje'}
# El resumen conserva relaciones estructurales; las de autoría aparecen en el completo.
principales = {
 ('perfil_docente','usuario'),('idea','usuario'),('proyecto','idea'),
 ('participante_proyecto','usuario'),('participante_proyecto','proyecto'),
 ('asignacion_proyecto','perfil_docente'),('asignacion_proyecto','proyecto'),
 ('proyecto_fase','proyecto'),('documento','proyecto_fase'),('documento_version','documento'),
 ('entrega_revision','proyecto_fase'),('entrega_documento_version','entrega_revision'),
 ('entrega_documento_version','documento_version'),('ciclo_revision','entrega_revision'),
 ('revision_entrega','ciclo_revision'),('solicitud','proyecto'),('respuesta_solicitud','solicitud'),
 ('acta_proyecto','acta'),('acta_proyecto','proyecto'),('mensaje','proyecto'),
 ('evento_auditoria','proyecto'),('notificacion','evento_auditoria'),
}


def generar(completo):
    seleccion = set(tablas) if completo else resumen
    detalle = '37 tablas · 212 campos · 66 claves foráneas' if completo else 'Vista general · 20 de 37 tablas · relaciones estructurales principales'
    titulo = 'MER COMPLETO' if completo else 'MER · VISTA GENERAL'
    leyenda = 'PK: clave primaria · FK: clave foránea · NULL: campo opcional'
    pie = 'Las cardinalidades describen filas históricas. Las restricciones de vigencia se explican en las notas.'
    direccion = 'LR' if completo else 'TB'
    lineas = ['digraph MER {', 'graph [rankdir='+direccion+', bgcolor="white", pad="0.5", nodesep="0.55", ranksep="0.9", splines=polyline, outputorder=edgesfirst, dpi=150, fontname="DejaVu Sans", fontsize=17, labelloc=t, labeljust=l, label=<<B>'+titulo+'</B><BR ALIGN="LEFT"/>Sistema Gestor de Proyectos de Grado · PostgreSQL / grado<BR ALIGN="LEFT"/><FONT POINT-SIZE="12">'+detalle+' · 19 octubre 2026<BR ALIGN="LEFT"/>'+leyenda+'<BR ALIGN="LEFT"/>'+pie+'</FONT>>];',
               'node [shape=plain, fontname="DejaVu Sans", fontsize=11];',
               'edge [fontname="DejaVu Sans", fontsize=9, fontcolor="#455A64", color="#83998D", penwidth=1.1, arrowsize=0.7, labeldistance=1.6];']
    for i, (grupo,(color,lista)) in enumerate(grupos.items()):
        elegidas = [t for t in lista if t in seleccion]
        if not elegidas:
            continue
        if completo:
            lineas += [f'subgraph cluster_{i} {{',f'label="{grupo}"; fontcolor="{color}"; fontsize=16; color="#DEE6E0"; style="rounded"; penwidth=1.2; margin=18;']
        for tabla in elegidas:
            lineas.append(f'"{tabla}" [label=<{etiqueta(tabla,completo)}>];')
        if completo:
            lineas.append('}')
    conteo = 0
    for hijo,padre,campos,referidos in relaciones:
        if hijo not in seleccion or padre not in seleccion or (not completo and (hijo,padre) not in principales):
            continue
        opcional = any(c['is_nullable']=='YES' for c in tablas[hijo] if c['column_name'] in campos)
        singular = any(u.issubset(set(campos)) for u in unicas[hijo])
        par = '0..1' if opcional else '1'
        hij = '0..1' if singular else '0..N'
        texto = ', label="'+', '.join(campos)+'"' if completo else ''
        lineas.append(f'"{padre}" -> "{hijo}" [dir=both, arrowtail="'+('teeodot' if opcional else 'teetee')+'", arrowhead="'+('teeodot' if singular else 'crowodot')+f'", taillabel="{par}", headlabel="{hij}"'+texto+'];')
        conteo += 1
    lineas.append('}')
    nombre = 'MER_completo' if completo else 'MER_general'
    (SALIDA/(nombre+'.dot')).write_text('\n'.join(lineas),encoding='utf-8')
    print(nombre+': '+str(len(seleccion))+' tablas; '+str(conteo)+' relaciones.')


if __name__ == '__main__':
    generar(False)
    generar(True)
