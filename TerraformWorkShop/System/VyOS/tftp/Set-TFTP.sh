#!/bin/vbash
sudo mkdir -p ${dir}
sudo chown ${user}:${group} ${dir}

# Ensure that we have the correct group or we'll corrupt the configuration
if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f $0) $@"
fi

source /opt/vyatta/etc/functions/script-template
configure
set service tftp-server directory ${dir}
set service tftp-server listen-address ${address}
set service tftp-server allow-upload

commit
save
