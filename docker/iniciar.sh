#!/bin/sh
set -eu

# El mismo puerto debe ser utilizado por Tomcat y por el router del alojamiento.
PORT=${PORT:-8080}
case "$PORT" in
    ''|*[!0-9]*) echo 'ARRANQUE_ERROR: PORT debe ser un número entre 1 y 65535.' >&2; exit 1 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo 'ARRANQUE_ERROR: PORT debe estar entre 1 y 65535.' >&2
    exit 1
fi
export CATALINA_OPTS="${CATALINA_OPTS:-} -Dgrado.http.port=$PORT"
echo "ARRANQUE: Tomcat escuchará en PORT=$PORT"
exec /usr/local/tomcat/bin/catalina.sh run
