terraform {
  required_providers {
    ldap = {
      source  = "l-with/ldap"
      version = ">=0.5.6"
    }
  }
}

provider "ldap" {
  host         = "opendj.mgmt.sololab"
  port         = "636"
  tls          = true
  tls_insecure = true

  bind_user     = "cn=Directory Manager"
  bind_password = "P@ssw0rd"
}

