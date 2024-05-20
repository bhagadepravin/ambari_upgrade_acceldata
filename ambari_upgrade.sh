#!/bin/bash
# Check if Ambari server is running
ambari_status=$(ambari-server status | grep "Ambari Server running")

if [ -z "$ambari_status" ]; then
    # Ambari server is not running
    echo "Ambari server is not running."
    read -p "Do you want to start the Ambari server? (yes/no) " start_ambari
    if [ "$start_ambari" = "yes" ]; then
        # Start the Ambari server
        ambari-server start
        if [ $? -eq 0 ]; then
            echo "Ambari server started successfully."
        else
            echo "Failed to start Ambari server. Exiting."
            exit 1
        fi
    else
        echo "Exiting without starting Ambari server."
        exit 1
    fi
else
    # Ambari server is already running
    echo "Ambari server is already running."
fi

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
WORKDIR="ambari_upgrade"
INVENTORY_FILE="hosts.ini"
MPACKS=("ambari-impala-mpack" "httpfs-ambari-mpack" "hue-ambari.mpack" "nifi-ambari-mpack" "spark3-ambari-3.2.2.mpack" "spark3-ambari-3.2.2-3.2.2.0-1.mpack") 

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
echo "[ambari_server_node]" > $INVENTORY_FILE
echo "$CURRENT_HOSTNAME ansible_host=$(hostname | awk '{print $1}') ansible_user=root ansible_password=Caps@Lock" >> $INVENTORY_FILE

echo "[ambari_agents]" >> $INVENTORY_FILE
while read -r HOST; do
  echo "$HOST ansible_host=$(getent hosts $HOST | awk '{ print $2 }') ansible_user=root ansible_password=Caps@Lock" >> $INVENTORY_FILE
done < hostcluster.txt

# Check and uninstall specified mpacks
#for MPACK in "${MPACKS[@]}"; do
#  if grep -qw $MPACK /var/lib/ambari-server/resources/mpacks/*/mpack.json; then
#    echo "Uninstalling mpack: $MPACK"
#    ambari-server uninstall-mpack --mpack-name=$MPACK
#  fi
#done

# Run the Ansible playbook
ansible-playbook -i $INVENTORY_FILE ../ambari_upgrade.yml

# Check the status
if [ $? -eq 0 ]; then
  echo "Ambari and ODP upgrade completed successfully."
else
  echo "Error: Ambari and ODP upgrade failed."
  exit 1
fi
