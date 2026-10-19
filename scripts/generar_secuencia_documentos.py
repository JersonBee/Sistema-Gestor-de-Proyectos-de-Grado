"""Dibuja la secuencia MVC en PNG y SVG; Pillow se utiliza solo para generar el artefacto."""
from pathlib import Path
from html import escape
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / 'docs/diagramas'
W, MAXH = 2640, 6500
imagen = Image.new('RGB', (W, MAXH), 'white')
d = ImageDraw.Draw(imagen)
svg = ['<rect width="100%" height="100%" fill="white"/>']
VERDE, GRIS = '#176B4A', '#566C61'
fuente = Path('C:/Windows/Fonts/arial.ttf')
negrita = Path('C:/Windows/Fonts/arialbd.ttf')


def font(tamano, bold=False):
    return ImageFont.truetype(str(negrita if bold else fuente), tamano)


def rect(x,y,w,h,fill='white',stroke='#B7CBC0',radius=10):
    d.rounded_rectangle((x,y,x+w,y+h),radius=radius,fill=fill,outline=stroke,width=2)
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')


def line(x1,y1,x2,y2,color=GRIS,dashed=False,width=2):
    if dashed:
        distancia=((x2-x1)**2+(y2-y1)**2)**0.5
        if distancia:
            for tramo in range(0,int(distancia),17):
                a,b=tramo/distancia,min(tramo+9,distancia)/distancia
                d.line((x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b),fill=color,width=width)
    else:
        d.line((x1,y1,x2,y2),fill=color,width=width)
    patron=' stroke-dasharray="9 8"' if dashed else ''
    svg.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}"{patron}/>')


def text(x,y,contenido,size=23,bold=False,color='#203A2E',anchor='middle'):
    d.text((x,y),contenido,font=font(size,bold),fill=color,anchor='mm' if anchor=='middle' else 'lm')
    svg.append(f'<text x="{x}" y="{y}" font-family="Arial, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" fill="{color}" text-anchor="{anchor}" dominant-baseline="central">{escape(contenido)}</text>')


def envolver(contenido,ancho,size=23):
    salida=[]
    for parrafo in contenido.split('\n'):
        actual=''
        for palabra in parrafo.split():
            candidata=(actual+' '+palabra).strip()
            if actual and d.textlength(candidata,font=font(size))>ancho:
                salida.append(actual);actual=palabra
            else:actual=candidata
        salida.append(actual)
    return salida


X=[235,775,1320,1855,2390]
text(70,58,'SECUENCIA · PRESENTACIÓN Y REVISIÓN DE DOCUMENTOS',38,True,VERDE,'start')
text(70,107,'Sistema Gestor de Proyectos de Grado · MVC con JSP / JSTL y PostgreSQL',25,False,GRIS,'start')
text(70,147,'Flecha continua: petición o llamada · Flecha discontinua: respuesta · Lectura de arriba hacia abajo',21,False,GRIS,'start')
cabeceras=[('USUARIO / NAVEGADOR','Estudiante o responsable de revisión'),('CONTROLADOR','JSP pública → WEB-INF/controladores'),('VISTA','WEB-INF/vistas · HTML + JSTL / EL'),('MODELO DE ACCESO','WEB-INF/modelo · JSTL SQL / JNDI'),('POSTGRESQL','Esquema grado · reglas y persistencia')]
for i,(titulo,detalle) in enumerate(cabeceras):
    line(X[i],300,X[i],MAXH-20,'#B8C8BF',True)
    rect(X[i]-220,190,440,104,VERDE,VERDE)
    text(X[i],222,titulo,25,True,'white')
    text(X[i],263,detalle,19,False,'white')
y=326


def seccion(titulo,subtitulo=''):
    global y
    rect(55,y,W-110,76,'#E7F1EA','#D2E2D8',5)
    text(80,y+25,titulo,26,True,VERDE,'start')
    if subtitulo:text(80,y+55,subtitulo,21,False,GRIS,'start')
    y+=104


def mensaje(origen,destino,etiqueta,retorno=False):
    global y
    ancho=abs(X[destino]-X[origen])-46
    filas=envolver(etiqueta,ancho,23)
    cx=(X[origen]+X[destino])/2
    alto=30*len(filas)
    rect(cx-ancho/2,y-13,ancho,alto+8,'white','white',2)
    for i,fila in enumerate(filas):text(cx,y+i*30,fila)
    yy=y+alto+10
    line(X[origen],yy,X[destino],yy,GRIS,retorno,3)
    signo=1 if X[destino]>X[origen] else -1
    puntos=[(X[destino],yy),(X[destino]-signo*15,yy-8),(X[destino]-signo*15,yy+8)]
    d.polygon(puntos,fill=GRIS)
    svg.append('<polygon points="'+' '.join(f'{a},{b}' for a,b in puntos)+f'" fill="{GRIS}"/>')
    y=yy+38


def nota(contenido,centro,ancho,fill='#FFF7E7'):
    global y
    filas=envolver(contenido,ancho-40,22)
    alto=34+29*len(filas)
    rect(centro-ancho/2,y-4,ancho,alto,fill,'#D7C7A5')
    for i,fila in enumerate(filas):text(centro,y+17+i*29,fila,22)
    y+=alto+22


seccion('1. EL ESTUDIANTE PRESENTA EL CONJUNTO','Propuesta: F-DC-124 + Turnitin · Informe: F-DC-125 + F-DC-129 + Turnitin · Adicionales opcionales')
mensaje(0,1,'POST /acciones/documentos-enviar.jsp')
mensaje(1,3,'Solicitar validación de sesión')
mensaje(3,4,'SELECT grado.validar_sesion(?)')
mensaje(4,3,'Usuario y rol vigentes',True)
mensaje(3,1,'Identidad autorizada',True)
nota('Valida rol estudiante, método POST, CSRF, identificador y tipo de seguimiento.',X[1],570)
mensaje(1,3,'Presentar proyecto, enlaces y adicionales')
mensaje(3,4,'SELECT grado.presentar_documentos(...)')
nota('Operación atómica: comprueba participación, fase, plazos y formatos.\nRegistra versiones, entrega y ciclo; asigna la revisión al director.\nConserva auditoría y genera avisos internos.',2180,790,'#ECF5EE')
mensaje(4,3,'ok, mensaje, recurso_id',True)
mensaje(3,1,'Resultado de la operación',True)
mensaje(1,0,'302 → /seguimiento.jsp?id=…&tipo=…',True)

seccion('2. CONSULTA DESPUÉS DEL ENVÍO · POST / REDIRECT / GET','El navegador consulta la página de destino; recargar no repite el POST.')
mensaje(0,1,'GET /seguimiento.jsp?id=…&tipo=…')
mensaje(1,3,'Consultar seguimiento autorizado')
mensaje(3,4,'SELECT de proyecto, entregas y revisiones')
mensaje(4,3,'Datos y responsable pendiente',True)
mensaje(3,1,'Resultados preparados',True)
mensaje(1,2,'Seleccionar vista y entregar datos')
mensaje(2,1,'HTML con textos escapados',True)
mensaje(1,0,'200 · seguimiento actualizado',True)

seccion('3. EL RESPONSABLE REVISA EL CONJUNTO','Esta secuencia se repite por separado: Director → Evaluador → Comité; cada uno inicia sesión con su cuenta.')
mensaje(0,1,'POST /acciones/revision-decidir.jsp')
mensaje(1,3,'Solicitar validación de sesión')
mensaje(3,4,'SELECT grado.validar_sesion(?)')
mensaje(4,3,'Usuario y rol vigentes',True)
mensaje(3,1,'Identidad autorizada',True)
nota('Comprueba rol de revisión, método POST, CSRF y parámetros.',X[1],720)
mensaje(1,3,'Comprobar contexto de la revisión')
mensaje(3,4,'SELECT vínculo revisión / proyecto / tipo')
mensaje(4,3,'Contexto coincidente o resultado vacío',True)
mensaje(3,1,'Resultado de la comprobación',True)
nota('Si la revisión no pertenece al proyecto o al recorrido indicado, rechaza con 403 antes de decidir.',X[1],720)
mensaje(1,3,'Registrar decisión y reporte obligatorio')
mensaje(3,4,'SELECT grado.decidir_revision(...)')

alto=380
rect(1450,y,1110,alto,'#FAFCFA','#799F88',2)
rect(1450,y,470,42,'#E5EFE8','#799F88',2)
text(1470,y+21,'alt · decisión académica en PostgreSQL',21,True,VERDE,'start')
text(1480,y+76,'[APROBADO]',23,True,VERDE,'start')
for i,fila in enumerate(['Director: abre revisión del evaluador en fase II.',
                         'Evaluador: el conjunto pasa al Comité.',
                         'Comité: aprueba y avanza a Informe I o a Final.']):
    text(1480,y+115+i*31,fila,22,False,'#203A2E','start')
line(1450,y+205,2560,y+205,'#799F88',True)
text(1480,y+239,'[RECHAZADO]',23,True,'#92513B','start')
for i,fila in enumerate(['Cierra el ciclo y devuelve el trámite al estudiante.',
                         'Registra reporte y plazo de corrección de tres días.',
                         'Reenvío completo → nueva revisión desde el director.']):
    text(1480,y+278+i*31,fila,22,False,'#203A2E','start')
y+=alto+30
nota('En ambos casos se conservan las decisiones, el historial y los avisos internos.',2180,790,'#ECF5EE')
mensaje(4,3,'ok, mensaje, recurso_id',True)
mensaje(3,1,'Resultado de la revisión',True)
mensaje(1,0,'302 → seguimiento; repetir consulta del bloque 2',True)

nota('SI SE SOLICITAN CORRECCIONES\nEl estudiante revisa el reporte y vuelve al bloque 1 con el conjunto completo.\nDespués de tres días recibe una alerta; el vencimiento no bloquea por sí solo el reenvío.',W/2,W-160)
nota('ALCANCE\nSe representa una sesión válida y el flujo de propuesta / informe; Pago se revisa únicamente por el Comité.\nPostgreSQL vuelve a verificar permisos y estado antes de escribir. Si una regla falla, devuelve ok=false y el controlador muestra el aviso sin avanzar.\nLos datos se acceden mediante el pool JNDI jdbc/Grado. No hay servlets ni DAOs propios.',W/2,W-160,'#F1F4F2')
H=y+30
assert H<MAXH
imagen.crop((0,0,W,H)).save(SALIDA/'SECUENCIA_DOCUMENTOS.png',dpi=(160,160))
cabecera=f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
(SALIDA/'SECUENCIA_DOCUMENTOS.svg').write_text(cabecera+'\n'+'\n'.join(svg)+'\n</svg>',encoding='utf-8')
print(f'Secuencia generada: PNG y SVG · {W} × {H} px · 5 participantes.')
