terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">=1.206.0"
    }
  }
  backend "oss" {
    profile             = "ap_sg"
    region              = "ap-southeast-1"
    bucket              = "terraform-remote-backend-root"
    prefix              = ""
    key                 = "devops-test/internet/terraform.tfstate"
    acl                 = "private"
    encrypt             = "false"
    tablestore_endpoint = "https://tf-ots-lock.ap-southeast-1.ots.aliyuncs.com"
    tablestore_table    = "terraform_remote_backend_lock_table_root"
  }
}

provider "alicloud" {
  profile = "ap_sg"
}
