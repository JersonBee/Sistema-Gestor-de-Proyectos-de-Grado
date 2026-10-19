"""Regresión de paginación con fechas idénticas. Solo grado_pruebas local."""
import html.parser
import secrets
import urllib.parse
from pruebas_acceso import Cliente, sql
from pruebas_flujo_inicial import literal

class Ideas(html.parser.HTMLParser):
    def __init__(self): super().__init__(); self.ids=[]
    def handle_starttag(self,tag,attrs):
        href=dict(attrs).get('href','')
        if tag=='a' and urllib.parse.urlsplit(href).path.endswith('/idea.jsp'):
            self.ids.extend(urllib.parse.parse_qs(urllib.parse.urlsplit(href).query).get('id',[]))

def verificar_empates():
    assert sql('SELECT current_database();').strip()=='grado_pruebas'
    clave=secrets.token_hex(12); prefijo='QA-Empates-'+secrets.token_hex(6)
    correo=prefijo.lower()+'@prueba.invalid'
    uid=sql("INSERT INTO grado.usuario(nombre,correo,contrasena_hash,rol_codigo,estado) VALUES("+literal(prefijo)+','+literal(correo)+',grado.crear_hash_contrasena('+literal(clave)+"),'director','activo') RETURNING id;").splitlines()[0]
    try:
        ids=sql(f"INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado,creado_en) SELECT {uid},(SELECT min(id) FROM grado.modalidad),(SELECT min(id) FROM grado.area_experiencia),(SELECT min(id) FROM grado.linea_investigacion),"+literal(prefijo)+"||' '||n,'Descripción','Objetivos','JSTL','aprobada',CURRENT_TIMESTAMP FROM generate_series(1,85) n RETURNING id;").splitlines()
        ids=[x for x in ids if x.isdigit()]
        assert len(ids)==85
        c=Cliente();status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo,'contrasena':clave})
        assert status==200 and '/panel.jsp' in url
        vistos=[]
        for pagina in (1,2,3,4,5):
            status,_,body,_=c.pedir('/ideas.jsp?'+urllib.parse.urlencode({'q':prefijo,'vista':'propias','pagina':pagina}))
            assert status==200
            parser=Ideas();parser.feed(body)
            parser.ids=list(dict.fromkeys(parser.ids))
            assert len(parser.ids)==(20 if pagina<5 else 5),(pagina,parser.ids)
            vistos+=parser.ids
        assert len(vistos)==len(set(vistos)), 'El banco repite ideas entre páginas cuando coinciden las fechas'
        assert set(vistos)==set(ids), 'El banco omite ideas cuando coinciden las fechas'
        print('OK: 85 ideas con fecha idéntica, cinco páginas completas sin duplicados ni omisiones.')
    finally:
        sql(f'DELETE FROM grado.idea WHERE autor_id={uid}; DELETE FROM grado.sesion_acceso WHERE usuario_id={uid}; DELETE FROM grado.usuario WHERE id={uid};')

if __name__=='__main__': verificar_empates()
