# Crea UNA instancia nueva y usa una subred existente.
# No administra ni modifica la VM Vixor anterior.
resource "oci_core_instance" "ubuntu_vm" {
  compartment_id      = var.compartment_ocid
  display_name        = "ubuntu-vixor-docker-terraform"
  availability_domain = var.availability_domain
  shape               = "VM.Standard.E5.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 2
  }

  source_details {
    source_type             = "image"
    source_id               = var.ubuntu_image_ocid
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = true
    display_name     = "vnic-ubuntu-web-terraform"
    hostname_label   = "ubuntu-web-terraform"
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(pathexpand(var.ssh_public_key_path)))
    user_data = base64encode(templatefile("${path.module}/scripts/bootstrap-docker.sh", {
      docker_image = var.docker_image
    }))
  }
}

output "public_ip" {
  value       = oci_core_instance.ubuntu_vm.public_ip
  description = "IP publica de la NUEVA VM."
}

output "web_url" {
  value       = "http://${oci_core_instance.ubuntu_vm.public_ip}"
  description = "Abrir cuando cloud-init termine de instalar Docker e iniciar Vixor."
}
