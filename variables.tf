variable "tenancy_ocid" {
  type        = string
  description = "OCID de TU tenancy de Oracle Cloud."
}

variable "user_ocid" {
  type        = string
  description = "OCID del usuario al que pertenece la clave API."
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint de la clave API registrada en Oracle."
}

variable "private_key_path" {
  type        = string
  description = "Ruta local al PEM privado de la clave API; no es la clave SSH."
  validation {
    condition     = fileexists(pathexpand(var.private_key_path))
    error_message = "No existe el PEM de la clave API en private_key_path."
  }
}

variable "region" {
  type        = string
  description = "Region donde se creara la VM; debe coincidir con imagen, AD y subred."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment donde se creara la instancia."
}

variable "ubuntu_image_ocid" {
  type        = string
  description = "OCID regional de una imagen Ubuntu x86_64 compatible con E2.1.Micro."
}

variable "ssh_public_key_path" {
  type        = string
  description = "Ruta local a la clave SSH PUBLICA (.pub) para acceder a Ubuntu."
  validation {
    condition     = fileexists(pathexpand(var.ssh_public_key_path))
    error_message = "No existe el archivo de clave publica SSH."
  }
}

variable "subnet_ocid" {
  type        = string
  description = "Subred publica EXISTENTE con ruta a internet y reglas TCP 22 y 80."
}

variable "availability_domain" {
  type        = string
  description = "Nombre completo del AD de TU tenancy, no solo AD-1."
}

variable "docker_image" {
  type        = string
  description = "Imagen publica de Docker Hub: usuario/repositorio:tag o usuario/repositorio@sha256:digest."
  default     = "sunner01/vixor-docker-auto:latest"
  validation {
    condition     = can(regex("^[a-z0-9]+/[a-z0-9._-]+(:[A-Za-z0-9_.-]+|@sha256:[a-f0-9]{64})$", var.docker_image))
    error_message = "Usa una imagen de Docker Hub con etiqueta o digest, sin espacios ni caracteres de shell."
  }
}