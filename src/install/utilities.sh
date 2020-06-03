#!/bin/bash

sudo systemctl stop ntpd.service
sudo systemctl status ntpd.service
sudo iptables -t nat -A POSTROUTING -p udp --sport 123 -j MASQUERADE --to-ports 1025-65535
sudo ntpdate ntp0.pipex.net
sudo yum downgrade leatherman


#edit /usr/share/openstack-puppet/modules/nova/manifests/db/sync.pp
#class nova::db::sync(
#  $extra_params    = undef,
#  $db_sync_timeout = 300,
#)
# change 300 into 3600
#Same for neutron
