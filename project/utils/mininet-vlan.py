############################################################################
##     This file is part of USMA CS484.
###############################################################################

import json
import argparse
import os

# Shell helper function
def cmdline(command):
    return os.popen(command).read()
    

# Enable VLAN interfaces on the Mininet hosts
def enable(scripts_dir, host_dict):
    for host in host_dict:
        vlan_id = host_dict[host]['vlan']

        ip_address = cmdline('{0}/utils/mn-stratum/exec-script {1} "hostname -I"'.format(
            scripts_dir, host)).strip()
        cmdline('{0}/utils/mn-stratum/exec-script {1} "ifconfig {1}-eth0 inet 0 && \
                                                       vconfig add {1}-eth0 {2} && \
                                                       ifconfig {1}-eth0.{2} inet {3}"'.format(
            scripts_dir, host, vlan_id, ip_address))
    print ("VLAN enabled")


# Disable VLAN interfaces on the Mininet hosts
def disable(scripts_dir, host_dict):
    for host in host_dict:
        vlan_id = host_dict[host]['vlan']

        ip_address = cmdline('{0}/utils/mn-stratum/exec-script {1} "hostname -I"'.format(
            scripts_dir, host)).strip()
        cmdline('{0}/utils/mn-stratum/exec-script {1} "vconfig rem {1}-eth0.{2} && \
                                                       ifconfig {1}-eth0 inet {3}"'.format(
            scripts_dir, host, vlan_id, ip_address))
    print ("VLAN disabled")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Vlan Utility Script')
    parser.add_argument('--scripts-dir', help='Scripts Directory', required=True,
                        type=str, action="store")
    parser.add_argument('--enable', help='Vlan Enable', action="store_true", default=False)
    parser.add_argument('--disable', help='Vlan Disable', action="store_true", default=False)
    parser.add_argument('--topo-config', help='Topology Configuration File', required=True,
                        type=str, action="store")
    args = parser.parse_args()

    with open(args.topo_config, 'r') as infile:
        topo_config = json.loads(infile.read())

    host_dict = topo_config['host']

    if args.enable:
        enable(args.scripts_dir, host_dict)
    elif args.disable:
        disable(args.scripts_dir, host_dict)
