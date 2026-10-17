"""Paginación con más de veinte registros creados por los flujos HTTP locales."""
import html.parser
import secrets
import urllib.parse
from pruebas_acceso import Cliente,sql
from pruebas_flujo_inicial import literal

class Pagina(html.parser.HTMLParser):
 def __init__(self): super().__init__();self.textos=set();self.links=[];self.anchor=None
 def handle_starttag(self,t,attrs):
  if t=='a': self.anchor=[dict(attrs).get('href',''),'']
 def handle_data(self,data):
  self.textos.add(data.strip())
  if self.anchor is not None: self.anchor[1]+=data
 def handle_endtag(self,t):
  if t=='a' and self.anchor is not None:self.links.append(self.anchor);self.anchor=None

def verificar_paginacion(clave=None):
 assert sql('SELECT current_database();').strip()=='grado_pruebas'
 if clave is None:
  clave=secrets.token_hex(12)
  sql("UPDATE grado.usuario SET contrasena_hash=grado.crear_hash_contrasena("+literal(clave)+") WHERE correo IN ('director@flujo.invalid','comite@flujo.invalid','pausado@flujo.invalid');")
 def ingreso(nombre,correo=None):
  c=Cliente();status,url,_,_=c.pedir('/acciones/ingresar.jsp',{'csrf':c.token(),'correo':correo or nombre+'@flujo.invalid','contrasena':clave})
  assert status==200 and url.endswith('/panel.jsp'),('Ingreso paginación',nombre,url)
  return c
 def post(c,accion,datos,vista):
  status,url,body,_=c.pedir('/acciones/'+accion+'.jsp',datos|{'csrf':c.token(vista)})
  assert status==200 and '/no-disponible.jsp' not in url,('Acción paginación',accion,status,url)
  return url,body
 def paginas(c,ruta,titulos=None):
  status,_,body,_=c.pedir(ruta);assert status==200
  p1=Pagina();p1.feed(body)
  link=next((href for href,texto in p1.links if 'Siguiente' in texto),None)
  assert link,('No ofreció segunda página',ruta)
  status,url,body,_=c.pedir(link);assert status==200 and 'pagina=2' in url
  p2=Pagina();p2.feed(body)
  assert any('Anterior' in t for _,t in p2.links),('Falta retorno',ruta)
  if titulos:
   visibles1=set(titulos)&p1.textos;visibles2=set(titulos)&p2.textos
   assert len(visibles1)==20 and len(visibles2)==1 and not visibles1&visibles2,('Contenido de páginas',ruta,len(visibles1),len(visibles2))
  for k,v in urllib.parse.parse_qs(urllib.parse.urlsplit(ruta).query).items():
   assert urllib.parse.parse_qs(urllib.parse.urlsplit(link).query).get(k)==v,('Perdió filtro',ruta,k)
  print('OK paginación: '+urllib.parse.urlsplit(ruta).path,flush=True)
 director=ingreso('director');comite=ingreso('comite')
 prefijo='QA-Paginacion-'+secrets.token_hex(3)
 titulos=[prefijo+' '+str(i).zfill(2) for i in range(1,22)]
 modalidad=sql("SELECT id FROM grado.modalidad WHERE codigo='desarrollo_software';").strip()
 ids=[]
 for titulo in titulos:
  url,_=post(director,'idea-crear',{'titulo':titulo,'modalidad':modalidad,'area':'Software','linea':'Sistemas de información','descripcion':'Prueba local de navegación','objetivos':'Verificar paginación','tecnologias':'JSTL'},'/idea-nueva.jsp')
  assert '/idea.jsp?' in url,url
  ids.append(urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)['id'][0])
 paginas(director,'/ideas.jsp?'+urllib.parse.urlencode({'q':prefijo,'vista':'propias'}),titulos)
 paginas(comite,'/tareas.jsp',titulos)
 for i,(idea,titulo) in enumerate(zip(ids,titulos)):
  post(comite,'idea-decidir',{'id':idea,'decision':'aprobada','reporte':'Aprobación de fixture de paginación'},'/idea.jsp?id='+idea)
  c=Cliente();correo=prefijo.lower()+str(i)+'@paginacion.invalid'
  url,_=post(c,'registrar',{'tipo':'estudiante','rol':'estudiante','nombre':titulo,'correo':correo,'contrasena':clave,'confirmacion':clave},'/registro.jsp')
  assert 'aviso=registro' in url
  c=ingreso('estudiante-paginación',correo)
  url,_=post(c,'proyecto-crear',{'idea':idea,'nombre':titulo},'/proyecto-nuevo.jsp?idea='+idea)
  assert '/pago.jsp?' in url,url
 paginas(comite,'/proyectos.jsp?'+urllib.parse.urlencode({'q':prefijo}),titulos)
 paginas(comite,'/usuarios.jsp?'+urllib.parse.urlencode({'q':prefijo}),titulos)
 activo=sql("SELECT id FROM grado.proyecto WHERE titulo='pausado';").strip()
 alumno=ingreso('pausado');uid=sql("SELECT id FROM grado.usuario WHERE correo='pausado@flujo.invalid';").strip()
 for texto in titulos:
  _,body=post(director,'mensaje-enviar',{'id':activo,'destinatario':uid,'contenido':texto},'/mensajes.jsp?id='+activo)
  assert 'Mensaje enviado' in body
 paginas(alumno,'/mensajes.jsp?id='+activo,titulos)
 paginas(alumno,'/avisos.jsp')
 paginas(comite,'/historial.jsp?id='+activo)
 print('OK: siete listados, segunda página, retorno, veinte registros por página y filtros conservados.')

if __name__=='__main__': verificar_paginacion()
