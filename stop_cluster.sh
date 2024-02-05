#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "${BASH_SOURCE}"))

clear

ansible -i $SCRIPT_DIR/piHatAnsible/hosts.ini in_hat -m shell -a "nohup bash -c 'sleep 5 && poweroff' &" -b

ansible -i $SCRIPT_DIR/piHatAnsible/hosts.ini master -m shell -a "sleep 15 && /sbin/clusterhat off && sleep 15"

ansible -i $SCRIPT_DIR/piHatAnsible/hosts.ini master -m shell -a "nohup bash -c 'sleep 5 && poweroff' &" -b
