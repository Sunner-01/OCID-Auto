terraform {
  required_version = ">= 1.12.0, < 2.0.0"
  backend "oci" {
    bucket              = "terraform-estado-practica"
    namespace           = "gr23tbuggx3b"
    key                 = "oci-vixor-docker/terraform.tfstate"
    config_file_profile = "DEFAULT"
  }
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0, < 9.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
