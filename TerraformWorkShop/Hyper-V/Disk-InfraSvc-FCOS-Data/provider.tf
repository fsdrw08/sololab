terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">=1.2.1"
    }
  }
  backend "pg" {
    conn_str    = "postgres://terraform:terraform@192.168.255.1/tfstate"
    schema_name = "HyperV-InfraSvc-Disk-FCOS"
  }
}

# https://registry.terraform.io/providers/taliesins/hyperv/latest/docs
provider "hyperv" {
  host     = var.hyperv.host
  port     = var.hyperv.port
  user     = var.hyperv.user
  password = var.hyperv.password
  https    = true
  insecure = true
  use_ntlm = true
  # tls_server_name = ""
  # cacert_path     = ""
  # cert_path       = ""
  # key_path        = ""
  script_path = "C:/Temp/terraform_%RAND%.cmd"
  timeout     = "30s"
}
