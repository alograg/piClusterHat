#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "${BASH_SOURCE}"))

clear

RESET_CNFIG=${1:-false}

requiered () {
  local REQUIRED_PKG=$1
  local PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
  echo "Checking for $REQUIRED_PKG: ${PKG_OK/install ok/}"
  if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
  fi
}

requiered_kubectl () {
  local REQUIRED_PKG="kubectl"
  echo -n "Checking for $REQUIRED_PKG:  "
  if [ ! -f /usr/bin/kubectl ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.4/bin/linux/amd64/kubectl
    chmod +x $SCRIPT_DIR/kubectl
    sudo mv $SCRIPT_DIR/kubectl /usr/bin/kubectl
    kubectl version --client
  else
    echo "installed"
  fi
}

set -e

echo "Config and Installing K3s"
echo -n "I need sudo "

# Request sudo access for root actions
sudo echo ok

requiered "sshpass"

requiered "ansible"

if [ ! -f /etc/ansible/ansible.cfg ]; then
  sudo mkdir -p /etc/ansible
  sudo cat << EOF > /etc/ansible/ansible.cfg
[defaults]
host_key_checking=false
EOF
fi

requiered_kubectl

if [ ! -f $SCRIPT_DIR/k3sa/site.yml ]; then
  echo "Downloading K3-Ansimble:"
  wget -qO- https://github.com/k3s-io/k3s-ansible/archive/refs/heads/master.tar.gz | tar zxf -
  mv -f $SCRIPT_DIR/k3s-ansible-master $SCRIPT_DIR/k3sa
  sed -i 's/k3s_cluster/piCluster/' $SCRIPT_DIR/k3sa/*.yml
  sed -i 's/: node/: in_hat/' $SCRIPT_DIR/k3sa/*.yml
  cat reboot-handler.yml > $SCRIPT_DIR/k3sa/roles/raspberrypi/handlers/main.yml
fi

if [ ! -f $SCRIPT_DIR/piHatAnsible/hosts.ini ] || $RESET_CNFIG ; then
  export ANSIBLE_HOST_KEY_CHECKING=False
  echo "# $(date)" > $SCRIPT_DIR/piHatAnsible/hosts.ini
  cat $SCRIPT_DIR/piHatAnsible/hosts.ini.base >> $SCRIPT_DIR/piHatAnsible/hosts.ini
  echo "Extractin IPs of PIs"
  for i in $(nmap -sn 192.168.1.0/24 -oG - | awk '/Up$/{print $3$2}' | grep -E -e 'cbridge|p[1-4]' | sed 's#[()]#/#g');
    do
        NAME_TO_IP="s$i/"
        CURRENT_IP="$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< $NAME_TO_IP)"
        ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R $CURRENT_IP
        sed -i $NAME_TO_IP $SCRIPT_DIR/piHatAnsible/hosts.ini
    done

  echo "Run Update Playbook "
  ansible-playbook -i $SCRIPT_DIR/piHatAnsible/hosts.ini --limit in_hat apt_upgrade.yml
  sleep 15
  ansible-playbook -i $SCRIPT_DIR/piHatAnsible/hosts.ini --limit master apt_upgrade.yml
  sleep 15
fi

set +e

ansible-playbook $SCRIPT_DIR/k3s_is_instaled.yml -i $SCRIPT_DIR/piHatAnsible/hosts.ini

if [ $? -eq 0 ]; then
  echo "K3s is installed \n"
  set -e
else
  echo "Run K3s Installation Playbook"
  for i in {1..5} ; do
    ansible-playbook $SCRIPT_DIR/k3sa/site.yml -i $SCRIPT_DIR/piHatAnsible/hosts.ini
    if [ $? -eq 0 ]; then
        sleep 15
        break
    fi
    echo "Error detected, trying again... try $i"
  done
  set -e
fi

echo "Obeniendo Configuracion from master"
ansible-playbook -i $SCRIPT_DIR/piHatAnsible/hosts.ini --limit master download-k3s-config.yml
sleep 15
sed -i '/export KUBECONFIG/d' ~/.bashrc
export KUBECONFIG=~/.kube/piHatAnsible
echo -e "export KUBECONFIG=$KUBECONFIG\n" >> ~/.bashrc
kubectl get nodes
kubectl describe node
