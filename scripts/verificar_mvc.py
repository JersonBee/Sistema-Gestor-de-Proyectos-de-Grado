"""Comprueba límites entre rutas, controladores, modelo JSTL y vistas."""
from pathlib import Path
import re

RAIZ=Path(__file__).resolve().parent.parent
WEB=RAIZ/'src/main/webapp'

def verificar():
    controladores=WEB/'WEB-INF/controladores'; modelo=WEB/'WEB-INF/modelo'; vistas=WEB/'WEB-INF/vistas'
    assert all(p.is_dir() for p in [controladores,modelo,vistas]), 'Falta una capa MVC'
    rutas=list(WEB.glob('*.jsp'))+list((WEB/'acciones').glob('*.jsp'))
    for ruta in rutas:
        rel=ruta.relative_to(WEB).as_posix()
        esperado='<%@ include file="/WEB-INF/controladores/'+rel+'" %>'
        assert ruta.read_text(encoding='utf-8').strip()==esperado, 'La ruta contiene lógica: '+rel
    for ruta in WEB.rglob('*.jsp'):
        texto=ruta.read_text(encoding='utf-8'); rel=ruta.relative_to(WEB).as_posix()
        if '<sql:' in texto:
            assert ruta.is_relative_to(modelo), 'SQL fuera del modelo: '+rel
        if ruta.is_relative_to(vistas):
            assert not re.search(r'<c:redirect\b|pageContext\.(request|response)|scope=[\"\x27]session|<c:remove\b',texto), 'Flujo o estado dentro de una vista: '+rel
            assert '/WEB-INF/modelo/' not in texto and '/WEB-INF/controladores/' not in texto, 'La vista invoca otra capa: '+rel
        if ruta.is_relative_to(controladores):
            assert not re.search(r'<!DOCTYPE|<(?:html|form|section|article)\b',texto,re.I), 'HTML dentro de un controlador: '+rel
        if ruta.is_relative_to(modelo):
            assert not re.search(r'<c:redirect\b|<!DOCTYPE|<(?:html|form|section|article)\b',texto,re.I), 'Presentación o navegación dentro del modelo: '+rel
        for destino in re.findall(r'<%@\s*include\s+file=[\"\x27](/[^\"\x27]+)[\"\x27]',texto):
            assert (WEB/destino.lstrip('/')).is_file(), 'Include inexistente: '+destino
    print(f'OK MVC: {len(rutas)} rutas, vistas sin SQL/flujo, controladores sin HTML/SQL, modelo separado e includes válidos.')

if __name__=='__main__': verificar()
