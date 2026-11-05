#!/bin/bash
# Terraform sustituye docker_image antes de enviar este archivo a cloud-init.
set -Eeuo pipefail
exec > >(tee -a /var/log/bootstrap-vixor.log) 2>&1
trap 'echo "ERROR: fallo la configuracion de Docker en la linea $LINENO" >&2' ERR

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
IMAGE='${docker_image}'
CONTAINER='vixor-web'

echo "Instalando Docker para ejecutar $IMAGE"
apt-get -o Acquire::Retries=3 update
apt-get -o Acquire::Retries=3 install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --location --retry 5 \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
ARCH=$(dpkg --print-architecture)
cat > /etc/apt/sources.list.d/docker.sources <<DOCKER_REPO
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $VERSION_CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_REPO

apt-get -o Acquire::Retries=3 update
apt-get -o Acquire::Retries=3 install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker

# Imagen publica: no se necesitan credenciales en user_data ni en el estado.
for attempt in 1 2 3; do
  if docker pull "$IMAGE"; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "No se pudo descargar $IMAGE desde Docker Hub" >&2
    exit 1
  fi
  sleep 10
done

# Tambien permite ejecutar de nuevo el script si esta VM tenia Nginx.
if systemctl cat nginx.service >/dev/null 2>&1; then
  systemctl disable --now nginx
fi

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  docker rm -f "$CONTAINER"
fi

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -p 80:3000 \
  "$IMAGE"

for attempt in $(seq 1 60); do
  if curl --fail --silent --max-time 5 http://127.0.0.1:80/ -o /dev/null; then
    echo "Vixor funciona dentro de Docker en el puerto 80."
    docker ps --filter "name=^/$CONTAINER$"
    exit 0
  fi
  sleep 2
done

docker logs --tail 80 "$CONTAINER"
echo "El contenedor no respondio HTTP correctamente." >&2
exit 1
