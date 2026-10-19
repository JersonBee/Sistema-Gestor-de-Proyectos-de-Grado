"""Historial documental por fase; SQL real del modelo en transacciones revertidas locales."""
import json
from pathlib import Path
import re
from pruebas_acceso import sql


def verificar_documentos_fases():
    assert sql('SELECT current_database();').strip() == 'grado_pruebas'
    modelo = Path(__file__).resolve().parent.parent / 'src/main/webapp/WEB-INF/modelo/proyecto/documentosFases.jsp'
    consulta = re.search(r'<sql:query[^>]*>(.*?)<sql:param', modelo.read_text(encoding='utf-8'), re.S).group(1)
    consulta = consulta.replace('?', ':pid')
    resultados = []
    for tipo, documento in [('propuesta', 'f_dc_124'), ('informe', 'f_dc_125')]:
        def consultar(etapa):
            return "SELECT json_build_object('etapa','"+etapa+"','filas',coalesce(json_agg(row_to_json(q)),'[]'::json)) FROM ("+consulta+") q;"
        instrucciones = fr"""
BEGIN;
DO $$ BEGIN IF current_database()<>'grado_pruebas' THEN RAISE EXCEPTION 'Solo pruebas locales'; END IF; END $$;
SELECT id AS alumno FROM grado.usuario WHERE rol_codigo='estudiante' ORDER BY id LIMIT 1 \gset
SELECT id AS director FROM grado.usuario WHERE rol_codigo='director' ORDER BY id LIMIT 1 \gset
SELECT id AS evaluador FROM grado.usuario WHERE rol_codigo='evaluador' ORDER BY id LIMIT 1 \gset
INSERT INTO grado.idea(autor_id,modalidad_id,area_id,linea_id,titulo,descripcion,objetivos,tecnologias,estado)
SELECT :alumno,(SELECT min(id) FROM grado.modalidad),(SELECT min(id) FROM grado.area_experiencia),(SELECT min(id) FROM grado.linea_investigacion),'QA historia de fases','Descripción','Objetivos','JSTL','aprobada' RETURNING id AS idea \gset
INSERT INTO grado.proyecto(idea_id,modalidad_id,titulo,objetivos,descripcion,creado_por)
SELECT id,modalidad_id,titulo,objetivos,descripcion,:alumno FROM grado.idea WHERE id=:idea RETURNING id AS pid \gset
INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en)
VALUES(:pid,'{tipo}_1',CURRENT_TIMESTAMP) RETURNING id AS fase1 \gset
INSERT INTO grado.proyecto_fase(proyecto_id,fase_codigo,iniciada_en,finalizada_en,estado)
VALUES(:pid,'{tipo}_2',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'rechazado');
INSERT INTO grado.documento(proyecto_id,proyecto_fase_id,tipo_codigo) VALUES(:pid,:fase1,'{documento}') RETURNING id AS doc \gset
INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) VALUES(:pid,:fase1,1,:alumno) RETURNING id AS entrega1 \gset
INSERT INTO grado.documento_version(documento_id,numero,url,registrado_por) VALUES(:doc,1,'https://documentos.invalid/version-original',:alumno) RETURNING id AS version1 \gset
INSERT INTO grado.entrega_documento_version VALUES(:entrega1,:pid,:doc,:version1);
INSERT INTO grado.ciclo_revision(entrega_id,numero,finalizado_en) VALUES(:entrega1,1,CURRENT_TIMESTAMP) RETURNING id AS ciclo1 \gset
INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id,decision,reporte_respuesta,decidida_en)
VALUES(:ciclo1,'evaluador',:evaluador,'rechazado','Corregir',CURRENT_TIMESTAMP);
INSERT INTO grado.entrega_revision(proyecto_id,fase_origen_id,numero,presentada_por) VALUES(:pid,:fase1,2,:alumno) RETURNING id AS entrega2 \gset
INSERT INTO grado.documento_version(documento_id,numero,url,registrado_por) VALUES(:doc,2,'https://documentos.invalid/version-corregida',:alumno) RETURNING id AS version2 \gset
INSERT INTO grado.entrega_documento_version VALUES(:entrega2,:pid,:doc,:version2);
INSERT INTO grado.ciclo_revision(entrega_id,numero) VALUES(:entrega2,1) RETURNING id AS ciclo2 \gset
INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id) VALUES(:ciclo2,'director',:director);
{consultar('antes')}
UPDATE grado.revision_entrega SET decision='aprobado',reporte_respuesta='Corregido',decidida_en=CURRENT_TIMESTAMP WHERE ciclo_id=:ciclo2;
UPDATE grado.proyecto_fase SET finalizada_en=CURRENT_TIMESTAMP,estado='aprobado' WHERE id=:fase1;
UPDATE grado.proyecto_fase SET finalizada_en=NULL,estado=NULL WHERE proyecto_id=:pid AND fase_codigo='{tipo}_2';
INSERT INTO grado.revision_entrega(ciclo_id,etapa,responsable_id) VALUES(:ciclo2,'evaluador',:evaluador);
{consultar('despues')}
ROLLBACK;
"""
        salida = sql(instrucciones)
        casos = [json.loads(linea) for linea in salida.splitlines() if linea.startswith('{')]
        assert len(casos) == 2
        for caso in casos:
            fase1 = [f for f in caso['filas'] if f['origen'] == tipo+'_1']
            fase2 = [f for f in caso['filas'] if f['origen'] == tipo+'_2']
            assert len(fase1) == 1 and fase1[0]['url'].endswith('version-corregida')
            esperada = 'version-original' if caso['etapa']=='antes' else 'version-corregida'
            assert len(fase2) == 1 and fase2[0]['url'].endswith(esperada), (tipo,caso['etapa'],'La fase II no conserva el conjunto que realmente llegó a revisión')
        resultados.append(tipo)
    print('OK: documentos históricos de '+', '.join(resultados)+' por fase, antes y después de llegar la corrección; fixtures revertidos.')


if __name__ == '__main__':
    verificar_documentos_fases()
