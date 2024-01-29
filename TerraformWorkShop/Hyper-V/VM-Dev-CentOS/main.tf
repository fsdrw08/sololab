locals {
  vhd_dir = "C:\\ProgramData\\Microsoft\\Windows\\Virtual Hard Disks"
  vm_name = var.vm_name
  count   = "1"
}

module "cloudinit_nocloud_iso" {
  source = "../modules/cloudinit_nocloud_iso2"
  count  = local.count
  cloudinit_config = {
    isoName = local.count <= 1 ? "cloud-init.iso" : "cloud-init${count.index + 1}.iso"
    part = [
      {
        filename = "meta-data"
        content  = <<-EOT
        instance-id: iid-dev-Fedora_202401
        local-hostname: Dev-CentOS
        EOT
      },
      {
        filename = "user-data"
        content  = <<-EOT
        #cloud-config
        # https://github.com/canonical/cloud-init/blob/main/config/cloud.cfg.tmpl#L112
        
        # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/configuring_and_managing_cloud-init_for_rhel_8/index#the-default-cloud-cfg-file_red-hat-support-for-cloud-init
        bootcmd:
          - mkdir -p /home/podmgr/consul.d/data
          - mkdir -p /home/podmgr/.config/systemd/user

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#write-files
        write_files:
          # Set-CgroupConfig
          # https://github.com/containers/podman/blob/main/troubleshooting.md#26-running-containers-with-resource-limits-fails-with-a-permissions-error
          - path: /etc/systemd/system/user@1001.service.d/ansible-podman-rootless-provision.conf
            owner: root:root
            content: |
              # BEGIN ansible-podman-rootless-provision systemd_cgroup_delegate
              [Service]
              Delegate=cpu cpuset io memory pids
              # END ansible-podman-rootless-provision systemd_cgroup_delegate
          # Set-SysctlParams
          # https://github.com/containers/podman/blob/main/troubleshooting.md#5-rootless-containers-cannot-ping-hosts
          - path: /etc/sysctl.d/ansible-podman-rootless-provision.conf
            owner: root:root
            content: |
              net.ipv4.ping_group_range=0 2000000
              net.ipv4.ip_unprivileged_port_start=53
          - path: /etc/systemd/system/consul.service
            content: |
              [Unit]
              Description="HashiCorp Consul - A service mesh solution"
              Documentation=https://www.consul.io/
              Requires=network-online.target
              After=network-online.target
              ConditionFileNotEmpty=/home/podmgr/consul.d/consul.hcl

              [Service]
              User=podmgr
              Group=podmgr
              Type=notify
              ExecStart=/usr/local/bin/consul agent -config-dir=/home/podmgr/consul.d/
              ExecReload=/bin/kill --signal HUP $MAINPID
              KillMode=process
              KillSignal=SIGTERM
              Restart=on-failure
              LimitNOFILE=65536

              [Install]
              WantedBy=multi-user.target
          - path: /home/podmgr/consul.d/consul.hcl
            defer: true
            owner: podmgr:podmgr
            content: |
              acl {
                tokens {
                  # https://developer.hashicorp.com/consul/docs/agent/config/config-files#acl_tokens_default
                  default = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
                }
              }
              auto_reload_config = true
              bind_addr = "{{ GetInterfaceIP `eth0` }}"
              datacenter = "dc1"
              data_dir = "/home/podmgr/consul.d/data/"
              encrypt = "qDOPBEr+/oUVeOFQOnVypxwDaHzLrD+lvjo5vCEBbZ0="
              retry_join = [
                "consul.service.consul"
              ]
              enable_local_script_checks = true
          # Set-JenkinsSwarmService
          - path: /home/podmgr/Trust-SelfSignCA.sh
            defer: true
            owner: podmgr:podmgr
            content: |
              #!/usr/bin/bash
              openssl s_client -showcerts -connect jenkins.service.consul:443 2>&- | \
              tac | \
              sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | \
              tac > /home/podmgr/root_ca.pem
              chmod 600 /home/podmgr/root_ca.pem && chown podmgr:podmgr /home/podmgr/root_ca.pem

              # copy to home dir
              if [[ -f /home/podmgr/cacerts ]]; then
                rm -f /home/podmgr/cacerts
              fi
              cp /etc/pki/ca-trust/extracted/java/cacerts /home/podmgr/cacerts 
              chmod 600 /home/podmgr/cacerts && chown podmgr:podmgr /home/podmgr/cacerts

              # add self sign cert to the backup cacerts
              # https://stackoverflow.com/questions/2138940/import-pem-into-java-key-store
              # https://backstage.forgerock.com/knowledge/kb/article/a94909995
              keytool -import -file /home/podmgr/root_ca.pem -alias consul -keystore /home/podmgr/cacerts -storepass changeit -noprompt
          # https://github.com/yunionio/ansible-role-jenkins-slave/blob/68ea66a6bf59e8d9589ed334e26dc399efceb330/tasks/main.yml#L23
          - path: /home/podmgr/.config/systemd/user/jenkins-swarm.service
            defer: true
            owner: podmgr:podmgr
            content: |
              [Unit]
              Description=Jenkins swarm client
              After=network.target
              AssertPathExists=/home/podmgr/cacerts
              AssertPathExists=/home/podmgr/swarm-client.jar

              [Service]
              Type=simple
              LimitNOFILE=65536
              Environment=LANG=en_US.UTF-8
              Environment=LC_ALL=en_US.UTF-8
              Environment=LANGUAGE=en_US.UTF-8
              Restart=always
              ExecStart=/usr/bin/java \
                -Djavax.net.ssl.trustStore=/home/podmgr/cacerts \
                -jar /home/podmgr/swarm-client.jar \
                -fsroot /home/podmgr/workspace \
                -url https://jenkins.service.consul/ \
                -name Dev-Fedora \
                -username admin \
                -password P@ssw0rd \
                -webSocket
              KillMode=process

              [Install]
              WantedBy=default.target
          - path: /home/podmgr/consul.d/jenkins-swarm.hcl
            defer: true
            owner: podmgr:podmgr
            content: |
              services {
                id      = "dev-centos-jenkins_swarm"
                name    = "dev-centos-jenkins_swarm"

                checks = [
                  {
                    id       = "dev-centos-jenkins_swarm-systemd"
                    name     = "dev-centos-jenkins_swarm-systemd"
                    args      = ["/usr/bin/systemctl", "--user", "is-active", "jenkins-swarm"]
                    interval = "20s"
                    timeout  = "2s"
                  }
                ]
              }

        # https://unix.stackexchange.com/questions/728955/why-is-the-root-filesystem-so-small-on-a-clean-fedora-37-install
        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#growpart
        growpart:
          mode: auto
          devices:
            - "/dev/sda3"
          ignore_growroot_disabled: false
        resize_rootfs: true

        # https://cloudinit.readthedocs.io/en/latest/reference/examples.html#disk-setup
        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#disk-setup
        # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/managing_storage_devices/disk-partitions_managing-storage-devices
        # disk_setup:
        #   /dev/sdb:
        #     table_type: gpt
        #     layout: true
        #     overwrite: False

        # fs_setup:
        #   - label: podmgr
        #     filesystem: 'xfs'
        #     device: '/dev/sdb1'
        #     partition: auto
        #     overwrite: false

        # https://cloudinit.readthedocs.io/en/latest/reference/examples.html#adjust-mount-points-mounted
        # https://zhuanlan.zhihu.com/p/250658106
        mounts:
          - [ "192.168.255.1:/mnt/data/nfs", /mnt/data, nfs4, "_netdev,auto", ]
        mount_default_fields: [ None, None, "auto", "nofail", "0", "2" ]

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#set-passwords
        ssh_pwauth: true

        # https://gist.github.com/wipash/81064e811c08191428002d7fe5da5ca7
        # https://cloudinit.readthedocs.io/en/latest/reference/examples.html#including-users-and-groups
        users:
          - name: admin
            gecos: admin
            groups: wheel
            plain_text_passwd: P@ssw0rd
            lock_passwd: false
            sudo: ALL=(ALL) NOPASSWD:ALL
            shell: /bin/bash
            ssh_import_id: None
            ssh_authorized_keys:
              - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
          - name: podmgr
            uid: 1001
            gecos: podmgr
            plain_text_passwd: podmgr
            lock_passwd: false
            shell: /bin/bash
            ssh_import_id: None
            ssh_authorized_keys:
              - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#yum-add-repo
        # https://github.com/AlmaLinux/cloud-images/blob/88cbbae32e5cd7f19f435b8ba5ec48d9024aa20b/build-tools-on-ec2-userdata.yml#L12
        # yum_repos:
        #   hashicorp:
        #     name: HashiCorp Stable - $basearch
        #     baseurl: https://rpm.releases.hashicorp.com/fedora/$releasever/$basearch/stable
        #     enabled: true
        #     gpgcheck: true
        #     gpgkey: https://rpm.releases.hashicorp.com/gpg

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#package-update-upgrade-install
        # https://stackoverflow.com/questions/46352173/ansible-failed-to-set-permissions-on-the-temporary
        package_update: true
        package_upgrade: true
        package_reboot_if_required: true
        packages:
          - nfs-utils
          - git
          - acl
          - python3-pip
          - python3-jmespath
          - cockpit
          - cockpit-pcp
          - cockpit-podman
          - podman
          - tftp
          - java-17-openjdk
        
        timezone: Asia/Shanghai
        
        # https://gist.github.com/corso75/582d03db6bb9870fbf6466e24d8e9be7
        runcmd:
          - chmod -R 700 /home/podmgr && chown -R podmgr:podmgr /home/podmgr
          - systemctl start mnt-data.mount
          - cp /mnt/data/bin/consul /usr/local/bin/consul
          - chmod 755 /usr/local/bin/consul
          - systemctl enable --now consul.service
          - sudo -u podmgr /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/$(id -u podmgr); /usr/bin/systemctl enable --now podman.socket --user; /usr/bin/systemctl enable --now consul.service --user"
          - bash /home/podmgr/Trust-SelfSignCA.sh
          - sudo -u podmgr /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/$(id -u podmgr); cd /home/podmgr/;/usr/bin/curl -O -k https://jenkins.service.consul/swarm/swarm-client.jar"
          - sudo -u podmgr /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/$(id -u podmgr); /usr/bin/systemctl enable --now jenkins-swarm.service --user"
          - firewall-offline-cmd --set-default-zone=trusted
          - firewall-offline-cmd --zone=trusted --add-service=cockpit
          - systemctl unmask firewalld
          - systemctl enable --now firewalld
          # https://access.redhat.com/solutions/5590021
          - firewall-cmd --permanent --new-policy tftp-client-data
          - firewall-cmd --permanent --policy tftp-client-data --add-ingress-zone HOST
          - firewall-cmd --permanent --policy tftp-client-data --add-egress-zone ANY
          - firewall-cmd --permanent --policy tftp-client-data --add-service tftp
          - firewall-cmd --reload
          - loginctl enable-linger podmgr
          # https://access.redhat.com/solutions/4661741
          # - cloud-init single --name cc_write_files --frequency once
          # - systemctl enable --now cockpit.socket
          # https://rakhesh.com/linux-bsd/failed-to-shellify-error-in-cloud-init/
          # - 'TOKEN=$(echo \"X-Consul-Token: e95b599e-166e-7d80-08ad-aee76e7ddf19\")'
          # - sudo -u podmgr /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/$(id -u podmgr); /usr/bin/curl -s -H $TOKEN -X GET -k https://consul.infra.sololab/v1/kv/config/script | jq -r .[0].Value | base64 --decode | bash"
          # - 'TOKEN=e95b599e-166e-7d80-08ad-aee76e7ddf19'
          # - sudo -u podmgr /bin/bash -c "export XDG_RUNTIME_DIR=/run/user/$(id -u podmgr); /usr/bin/curl -s -H "X-Consul-Token: $TOKEN" -X GET -k https://consul.infra.sololab/v1/kv/config/script | jq -r .[0].Value | base64 --decode | bash"

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#power-state-change
        # power_state:
        #   delay: 1
        #   mode: reboot
        #   message: reboot
        #   timeout: 30
        #   condition: true
        EOT
      },
      {
        filename = "network-config"
        # https://cloudinit.readthedocs.io/en/latest/reference/network-config.html#network-configuration-outputs
        content = <<-EOT
        version: 2
        ethernets:
          eth0:
            dhcp4: false
            addresses:
              - 192.168.255.1${count.index + 2}/255.255.255.0
            gateway4: 192.168.255.1
            nameservers:
              addresses: 192.168.255.1
        EOT
      }
    ]
  }
}


resource "null_resource" "remote" {
  depends_on = [module.cloudinit_nocloud_iso]
  count      = local.count
  triggers = {
    # https://discuss.hashicorp.com/t/terraform-null-resources-does-not-detect-changes-i-have-to-manually-do-taint-to-recreate-it/23443/3
    manifest_sha1 = sha1(jsonencode(module.cloudinit_nocloud_iso[count.index].cloudinit_config))
    vhd_dir       = local.vhd_dir
    vm_name       = local.count <= 1 ? "${var.vm_name}" : "${var.vm_name}${count.index + 1}"
    # https://github.com/Azure/caf-terraform-landingzones/blob/a54831d73c394be88508717677ed75ea9c0c535b/caf_solution/add-ons/terraform_cloud/terraform_cloud.tf#L2
    isoName  = module.cloudinit_nocloud_iso[count.index].isoName
    host     = var.hyperv_host
    user     = var.hyperv_user
    password = sensitive(var.hyperv_password)
  }

  connection {
    type     = "winrm"
    host     = self.triggers.host
    user     = self.triggers.user
    password = self.triggers.password
    use_ntlm = true
    https    = true
    insecure = true
    timeout  = "20s"
  }
  # copy to remote
  provisioner "file" {
    source = module.cloudinit_nocloud_iso[count.index].isoName
    # destination = "C:\\ProgramData\\Microsoft\\Windows\\Virtual Hard Disks\\${each.key}\\cloud-init.iso"
    destination = join("/", ["${self.triggers.vhd_dir}", "${self.triggers.vm_name}\\${self.triggers.isoName}"])
  }

  # for destroy
  provisioner "remote-exec" {
    when = destroy
    inline = [<<-EOT
      Powershell -Command "$cloudinit_iso=(Join-Path -Path '${self.triggers.vhd_dir}' -ChildPath '${self.triggers.vm_name}\${self.triggers.isoName}'); if (Test-Path $cloudinit_iso) { Remove-Item $cloudinit_iso }"
    EOT
    ]
  }
}

resource "hyperv_vhd" "boot_disk" {
  path = join("\\", [
    local.vhd_dir,
    var.vm_name,
    element(split("\\", var.source_disk), length(split("\\", var.source_disk)) - 1)
    ]
  )
  source = var.source_disk
}

module "hyperv_machine_instance" {
  source     = "../modules/hyperv_instance"
  depends_on = [null_resource.remote]
  count      = local.count

  vm_instance = {
    name                 = local.count <= 1 ? var.vm_name : "${var.vm_name}${count.index + 1}"
    checkpoint_type      = "Disabled"
    dynamic_memory       = true
    generation           = 2
    memory_maximum_bytes = 8191475712
    memory_minimum_bytes = 2147483648
    memory_startup_bytes = 2147483648
    notes                = "This VM instance is managed by terraform"
    processor_count      = 4
    state                = "Off"

    vm_firmware = {
      console_mode                    = "Default"
      enable_secure_boot              = "On"
      secure_boot_template            = "MicrosoftUEFICertificateAuthority"
      pause_after_boot_failure        = "Off"
      preferred_network_boot_protocol = "IPv4"
      boot_order = [
        {
          boot_type           = "HardDiskDrive"
          controller_number   = "0"
          controller_location = "0"
        },
      ]
    }

    vm_processor = {
      compatibility_for_migration_enabled               = false
      compatibility_for_older_operating_systems_enabled = false
      enable_host_resource_protection                   = false
      expose_virtualization_extensions                  = false
      hw_thread_count_per_core                          = 0
      maximum                                           = 100
      maximum_count_per_numa_node                       = 4
      maximum_count_per_numa_socket                     = 1
      relative_weight                                   = 100
      reserve                                           = 0
    }

    integration_services = {
      "Guest Service Interface" = true
      "Heartbeat"               = true
      "Key-Value Pair Exchange" = true
      "Shutdown"                = true
      "Time Synchronization"    = true
      "VSS"                     = true
    }

    network_adaptors = [
      {
        name        = "Internal Switch"
        switch_name = "Internal Switch"
      }
    ]

    dvd_drives = [
      {
        controller_number   = 0
        controller_location = 1
        path = local.count <= 1 ? join("\\", [
          "${local.vhd_dir}",
          "${var.vm_name}",
          "${module.cloudinit_nocloud_iso[count.index].isoName}"
          ]) : join("\\", [
          "${local.vhd_dir}",
          "${var.vm_name}${count.index + 1}",
          "${module.cloudinit_nocloud_iso[count.index].isoName}"
        ])
      }
    ]

    hard_disk_drives = [
      {
        controller_type     = "Scsi"
        controller_number   = "0"
        controller_location = "0"
        path                = hyperv_vhd.boot_disk.path
      },
    ]
  }
}
