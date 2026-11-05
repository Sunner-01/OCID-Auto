# Ubuntu + Docker + Vixor con Terraform

Este proyecto crea una VM nueva E5.Flex (1 OCPU, 2 GB RAM) en Oracle Cloud y arranca Vixor desde
la imagen publica sunner01/vixor-docker-auto:latest, publicada por GitHub Actions.
La VM Vixor anterior no pertenece a este estado y no se modifica.

## Archivos

- main.tf: crea la VM y envia el script externo mediante metadata.user_data.
- scripts/bootstrap-docker.sh: instala Docker desde el repositorio oficial,
  descarga la imagen y publica el contenedor vixor-web con puertos 80:3000.
- variables.tf: entradas de Oracle y variable docker_image.
- terraform.tfvars: configuracion local de tu cuenta; no subir a GitHub.
- provider.tf y .terraform.lock.hcl: proveedor OCI, version y estado remoto.
- .github/workflows/despliegue.yaml: despliegue automatico al subir a main.

No se instala Nginx ni se copia index.html. Node y Next.js estan dentro de la imagen.
Terraform utiliza templatefile para sustituir ${docker_image} dentro del script y
base64encode para enviarlo a Oracle. Cloud-init lo ejecuta como root al primer arranque.
No hace falta provisioner local-exec ni conectarse por SSH para instalar Docker.
El script solo se envia a la VM; nunca se ejecuta Bash en tu computadora Windows.

## Configuracion

Los datos de cuenta, dominio, subred e imagen Ubuntu ya se consultaron en Oracle.
El PEM API y la clave SSH .pub permanecen en Windows. El PEM API NO se envia a la VM.
La imagen Docker es publica; no se incluyen tokens ni contrasenas de Docker Hub.

## Despliegue con GitHub Actions

En el repositorio OCID-Auto, crea los diez secretos de Actions usados por
`.github/workflows/despliegue.yaml`. `OCI_API_KEY_PEM` debe contener el PEM
privado completo de la clave API de OCI, y `TF_VAR_SSH_PUBLIC_KEY` debe contener
la linea completa de la clave SSH publica. No subas el PEM ni la clave SSH
privada al repositorio.

Nombres exactos: `OCI_API_KEY_PEM`, `TF_VAR_TENANCY_OCID`,
`TF_VAR_COMPARTMENT_OCID`, `OCID_USER_OCID`, `TF_VAR_SUBNET_OCID`,
`TF_VAR_UBUNTU_IMAGE_OCID`, `TF_VAR_SSH_PUBLIC_KEY`,
`TF_VAR_AVAILABILITY_DOMAIN`, `OCID_FINGERPRINT` y `OCI_REGION`.

Cada push a `main` ejecuta Terraform con la VM E5.Flex de pago. El estado
se guarda en el bucket privado `terraform-estado-practica`, namespace
`gr23tbuggx3b`, objeto `oci-vixor-docker/terraform.tfstate`. El bucket debe
existir y el usuario API debe poder leer y escribir sus objetos. Si OCI informa
`Out of host capacity`, la accion reintenta cinco veces y luego falla.

Si la VM ya existe, un nuevo push ejecuta el plan y aplica cambios cuando los
hay. El contenedor dentro de una VM existente no se actualiza solo porque
Docker Hub haya publicado una nueva imagen con la misma etiqueta `latest`.
En terraform.tfvars puedes elegir una etiqueta o un digest, por ejemplo:

```hcl
docker_image = "sunner01/vixor-docker-auto:latest"
```

La subred existente debe tener salida a internet y permitir entrada TCP 80 y 22.
Docker configura la publicacion del puerto en el firewall del host. No se desactiva
el firewall ni se agregan reglas que permitan todo el trafico.

## Ejecutar EN WINDOWS (Warp / PowerShell local, no por SSH)

```powershell
cd "C:\Users\irisc\Downloads\oci_ubuntu\oci_ubuntu"
terraform init
terraform fmt -check
terraform validate
terraform plan -out="docker.tfplan"
```

Revisa el plan. Para una instalacion nueva debe indicar 1 to add, 0 to change,
0 to destroy. Cuando quieras crear la VM segun ese plan:

```powershell
terraform apply "docker.tfplan"
terraform output -raw web_url
```

apply con un plan guardado crea los recursos sin otra pregunta de confirmacion.
No uses el plan anterior practica.tfplan: desplegaba Nginx y HTML y se archivo
en el respaldo. Espera unos minutos tras RUNNING para que se descargue la imagen.
Abre la direccion con HTTP; HTTPS no esta configurado.

El estado de Terraform se guarda en el bucket OCI mencionado arriba. Para usar
Terraform localmente, configura tambien `~/.oci/config` con la misma clave API.
La carpeta `.terraform` local contiene el proveedor y no se sube a GitHub.

## Comprobar EN LA VM NUEVA

Desde tu Windows, sustituye IP_NUEVA por la salida de Terraform:

```powershell
ssh -i "C:\Users\irisc\Downloads\ssh-key-2026-10-05.key" ubuntu@IP_NUEVA
```

Ya conectado a Ubuntu:

```bash
sudo cloud-init status --wait
sudo docker ps
sudo docker logs --tail 50 vixor-web
curl -I http://127.0.0.1:80
sudo docker inspect --format '{{.Config.Image}}' vixor-web
```

Para diagnosticar un fallo de instalacion:

```bash
sudo tail -n 80 /var/log/bootstrap-vixor.log
sudo tail -n 80 /var/log/cloud-init-output.log
```

Cerrar Warp no detiene el contenedor. Docker y el contenedor quedan habilitados
para volver a arrancar tras reiniciar, salvo que detengas el contenedor manualmente.

## Cambios posteriores

Cloud-init ejecuta user_data al primer arranque. Cambiar el script o docker_image
en Terraform no vuelve a ejecutarlo dentro de una VM existente. Si la VM ya existe,
revisa el plan y decide si actualizar el contenedor por SSH o reemplazar la instancia.
No uses destroy ni -replace automaticamente.
La etiqueta latest se descarga durante el arranque; no se actualiza sola con cada push.
Para reproducir exactamente una version utiliza el tag SHA de GitHub Actions o un digest.

La VM E5.Flex genera cargos mientras este creada; plan valida la configuracion,
pero no garantiza capacidad de Oracle al crear.

Referencias:
https://docs.docker.com/engine/install/ubuntu/
https://developer.hashicorp.com/terraform/language/functions/templatefile
