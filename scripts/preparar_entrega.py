"""Exporta únicamente archivos publicables; no publica ni modifica la base."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DESTINO = ROOT / 'entrega'


def preparar():
    resultado = subprocess.run(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        cwd=ROOT, check=True, capture_output=True,
    )
    nombres = sorted(set(resultado.stdout.decode('utf-8').split('\0')) - {''})
    archivos = []
    secretos = []
    entorno = ROOT / '.env'
    if entorno.exists():
        for linea in entorno.read_text(encoding='utf-8-sig').splitlines():
            clave, separador, valor = linea.partition('=')
            if separador and any(p in clave.upper() for p in ('PASSWORD', 'SECRET', 'TOKEN')):
                valor = valor.strip().strip('\"\'')
                if len(valor) >= 8:
                    secretos.append(valor.encode())
    for nombre in nombres:
        ruta = ROOT / nombre
        partes = Path(nombre).parts
        if any(p in {'.git', '.tools', 'tmp', 'target', 'entrega', '.vercel', '__pycache__'} for p in partes):
            raise SystemExit('Archivo privado seleccionado: ' + nombre)
        if (ruta.name.startswith('.env') and ruta.name != '.env.example') or ruta.suffix.lower() in {'.key', '.p12', '.pfx', '.log', '.pyc'}:
            raise SystemExit('Archivo privado seleccionado: ' + nombre)
        if ruta.is_symlink():
            raise SystemExit('Revisar enlace antes de exportar: ' + nombre)
        if not ruta.is_file():
            continue
        contenido = ruta.read_bytes()
        if any(secreto in contenido for secreto in secretos):
            raise SystemExit('Posible credencial local en: ' + nombre)
        # El ejecutable POSIX debe conservar LF incluso al copiar desde Windows.
        if nombre == 'mvnw':
            contenido = contenido.replace(b'\r\n', b'\n')
        archivos.append((nombre, contenido))
    requeridos = {'Dockerfile.vercel', 'pom.xml', 'mvnw', '.mvn/wrapper/maven-wrapper.properties', '.env.example', 'docs/GITHUB_Y_VERCEL.md'}
    if not requeridos.issubset({n for n, _ in archivos}):
        raise SystemExit('Faltan archivos necesarios para construir la entrega.')
    DESTINO.mkdir(exist_ok=True)
    salida = DESTINO / 'proyectos-grado-fuentes.zip'
    manifiesto = []
    with zipfile.ZipFile(salida, 'w', zipfile.ZIP_DEFLATED) as zip:
        for nombre, contenido in archivos:
            info = zipfile.ZipInfo(nombre, (2026, 10, 17, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100755 if nombre == 'mvnw' else 0o100644) << 16
            zip.writestr(info, contenido)
            manifiesto.append({'archivo': nombre, 'sha256': hashlib.sha256(contenido).hexdigest()})
    (DESTINO / 'manifiesto.json').write_text(json.dumps(manifiesto, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(salida) as zip:
        assert zip.testzip() is None
    print(f'ENTREGA_OK: {len(archivos)} archivos; ZIP íntegro, sin credenciales locales detectadas.')
    print(salida)


if __name__ == '__main__':
    preparar()
