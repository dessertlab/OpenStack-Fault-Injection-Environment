#!/bin/bash

sudo systemctl stop ntpd.service
sudo systemctl status ntpd.service
sudo iptables -t nat -A POSTROUTING -p udp --sport 123 -j MASQUERADE --to-ports 1025-65535
sudo ntpdate ntp0.pipex.net
sudo yum downgrade leatherman
