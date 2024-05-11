vm_conn = {
  host     = "192.168.255.1"
  port     = 22
  user     = "vyos"
  password = "vyos"
}

# https://github.com/OpenIdentityPlatform/OpenDJ/blob/fe3b09f4a34ebc81725fd7263990839afd345752/opendj-packages/opendj-docker/Dockerfile-alpine
runas = {
  uid         = 1001
  gid         = 1000
  take_charge = false
}

data_dirs = "/mnt/data/opendj"

container = {
  network = {
    create      = true
    name        = "opendj"
    cidr_prefix = "172.16.3.0/24"
    address     = "172.16.3.10"
  }
  workload = {
    name        = "opendj"
    image       = "docker.io/openidentityplatform/opendj:4.6.2"
    local_image = "/mnt/data/offline/images/docker.io_openidentityplatform_opendj_4.6.2.tar"
    others = {
      "memory" = "1024"

      "environment TZ value"            = "Asia/Shanghai"
      "environment BASE_DN value"       = "dc=root,dc=sololab"
      "environment ROOT_PASSWORD value" = "P@ssw0rd"
      # pkcs12 doesn't work, use jks instead
      # "environment OPENDJ_SSL_OPTIONS value" = "--usePkcs12keyStore /cert/opendj.pfx --keyStorePassword changeit"
      "environment OPENDJ_SSL_OPTIONS value" = "--useJavaKeystore /opt/opendj/certs/keystore --keyStorePassword changeit"

      "volume opendj_cert source"      = "/etc/opendj/certs"
      "volume opendj_cert destination" = "/opt/opendj/certs"
      "volume opendj_data source"      = "/mnt/data/opendj"
      "volume opendj_data destination" = "/opt/opendj/data"
      # https://github.com/OpenIdentityPlatform/OpenDJ/blob/fe3b09f4a34ebc81725fd7263990839afd345752/opendj-packages/opendj-docker/Dockerfile
      # https://github.com/OpenIdentityPlatform/OpenDJ/blob/master/opendj-packages/opendj-docker/bootstrap/setup.sh#L39-L49
      "volume opendj_schema source"      = "/etc/opendj/schema"
      "volume opendj_schema destination" = "/opt/opendj/bootstrap/schema"
    }
  }
}

reverse_proxy = {
  ldap_frontend = {
    path = "load-balancing reverse-proxy service tcp389"
    configs = {
      "listen-address" = "192.168.255.1"
      "port"           = "389"
      "mode"           = "tcp"
      "backend"        = "opendj_ldap"
    }
  }
  ldap_backend = {
    path = "load-balancing reverse-proxy backend opendj_ldap"
    configs = {
      "mode"                = "tcp"
      "server vyos address" = "172.16.3.10"
      "server vyos port"    = "1389"
    }
  }
  ldaps_frontend = {
    path = "load-balancing reverse-proxy service tcp636"
    configs = {
      "listen-address" = "192.168.255.1"
      "port"           = "636"
      "mode"           = "tcp"
      "backend"        = "opendj_ldaps"
    }
  }
  ldaps_backend = {
    path = "load-balancing reverse-proxy backend opendj_ldaps"
    configs = {
      "mode"                = "tcp"
      "server vyos address" = "172.16.3.10"
      "server vyos port"    = "1636"
    }
  }
}

dns_record = {
  host = "opendj.mgmt.sololab"
  ip   = "192.168.255.1"
}
