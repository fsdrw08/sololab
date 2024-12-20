vm_conn = {
  host     = "192.168.255.20"
  port     = 22
  user     = "podmgr"
  password = "podmgr"
}

certs = {
  cert_content_tfstate_ref    = "../../TLS/RootCA/terraform.tfstate"
  cert_content_tfstate_entity = "etcd"
  cacert_basename             = "ca.crt"
  cert_basename               = "server.crt"
  key_basename                = "server.key"
}

podman_kube = {
  helm = {
    name   = "etcd"
    chart  = "../../../HelmWorkShop/helm-charts/charts/etcd"
    values = "./podman-etcd/values-sololab.yaml"
  }
  yaml_file_path = "/home/podmgr/.config/containers/systemd/etcd-aio.yaml"
}

podman_quadlet = {
  quadlet = {
    file_contents = [
      {
        file_source = "./podman-etcd/etcd-container.kube"
        # https://stackoverflow.com/questions/63180277/terraform-map-with-string-and-map-elements-possible
        vars = {
          yaml          = "etcd-aio.yaml"
          PodmanArgs    = "--tls-verify=false"
          KubeDownForce = "true"
        }
      },
    ]
    file_path_dir = "/home/podmgr/.config/containers/systemd"
  }
  service = {
    name   = "etcd-container"
    status = "start"
  }
}

container_restart = {
  systemd_path_unit = {
    content = {
      templatefile = "./podman-etcd/restart.path"
      vars = {
        PathModified = "/home/podmgr/.config/containers/systemd/etcd-aio.yaml"
      }
    }
    path = "/home/podmgr/.config/systemd/user/etcd_restart.path"
  }
  systemd_service_unit = {
    content = {
      templatefile = "./podman-etcd/restart.service"
      vars = {
        AssertPathExists = "/run/user/1001/systemd/generator/etcd-container.service"
        target_service   = "etcd-container.service"
      }
    }
    path = "/home/podmgr/.config/systemd/user/etcd_restart.service"
  }

}
