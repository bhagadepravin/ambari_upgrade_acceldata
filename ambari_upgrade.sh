#!/bin/bash

# Display the prompt for Spark3 service installation
read -p "Do you have Spark3 service installed in Ambari? (yes/no) " spark3_installed

# Check if Spark3 service is installed
if [[ "$spark3_installed" == "yes" ]]; then
    # Prompt the user for executing the backup script
    read -p "Did you execute generate_sql_backup_restore.sh script? (yes/no) " backup_executed
    # If the backup script is not executed, exit
    if [[ "$backup_executed" == "no" ]]; then
        echo "Please execute the generate_sql_backup_restore.sh script and then rerun this script."
        exit 1
    fi
fi

# Continue with the Ambari upgrade process
echo "Continuing with the Ambari upgrade process..."

# Variables
AMBARI_API_USER="admin"
AMBARI_API_PASS="admin"
AMBARI_API_URL="http://localhost:8080/api/v1/hosts"
SSH_SETUP_SCRIPT_URL="http://10.90.9.51/one_click_scripts/passwordless-ssh/setup_ssh_passwordless.sh"
#ANSIBLE_PLAYBOOK_URL="http://path_to_your_ansible_playbook/ambari_upgrade.yml"
WORKDIR="ambari_upgrade"
INVENTORY_FILE="hosts.ini"
MPACKS=("ambari-impala-mpack" "httpfs-ambari-mpack" "hue-ambari.mpack" "nifi-ambari-mpack" "spark3-ambari-3.2.2.mpack" ""spark3-ambari-3.2.2-3.2.2.0-1.mpack"") 

# Create a directory for the upgrade process
mkdir -p $WORKDIR
cd $WORKDIR

# Check if Ansible is installed
if ! command -v ansible &> /dev/null
then
    echo "Ansible is not installed. Installing now..."
    sudo yum install -y ansible
else
    echo "Ansible is already installed."
fi

# Download and execute the passwordless SSH setup script
wget -N $SSH_SETUP_SCRIPT_URL -O setup_ssh_passwordless.sh
chmod +x setup_ssh_passwordless.sh
./setup_ssh_passwordless.sh

# Retrieve the list of hosts from Ambari server
curl -s -u $AMBARI_API_USER:$AMBARI_API_PASS $AMBARI_API_URL | grep host_name | sed -n 's/.*"host_name" : "\([^\"]*\)".*/\1/p' > hostcluster.txt

# Verify hostcluster.txt is not empty
if [ ! -s hostcluster.txt ]; then
  echo "Error: No hosts found in Ambari server."
  exit 1
fi

# Get the current hostname
CURRENT_HOSTNAME=$(hostname)

# Create Ansible inventory file
echo "[ambari_server]" > $INVENTORY_FILE
echo "$CURRENT_HOSTNAME ansible_host=$(hostname -I | awk '{print $1}')" >> $INVENTORY_FILE

echo "[ambari_agents]" >> $INVENTORY_FILE
while read -r HOST; do
  echo "$HOST ansible_host=$(getent hosts $HOST | awk '{ print $1 }')" >> $INVENTORY_FILE
done < hostcluster.txt

# Check and uninstall specified mpacks
#for MPACK in "${MPACKS[@]}"; do
#  if grep -qw $MPACK /var/lib/ambari-server/resources/mpacks/*/mpack.json; then
#    echo "Uninstalling mpack: $MPACK"
#    ambari-server uninstall-mpack --mpack-name=$MPACK
#  fi
#done

# Restart Ambari server to apply changes
#ambari-server restart

# Download the Ansible playbook
#wget -N $ANSIBLE_PLAYBOOK_URL -O ambari_upgrade.yml

#get the Ansible playbook
#cp ../ambari_upgrade.yml $WORKDIR/

# Run the Ansible playbook
ansible-playbook -i $INVENTORY_FILE ../ambari_upgrade.yml

# Check the status
if [ $? -eq 0 ]; then
  echo "Ambari and ODP upgrade completed successfully."
else
  echo "Error: Ambari and ODP upgrade failed."
  exit 1
fi
