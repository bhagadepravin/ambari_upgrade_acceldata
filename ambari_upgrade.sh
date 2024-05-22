#!/bin/bash

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print messages in color
print_green() { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_red() { echo -e "${RED}$1${NC}"; }

# Check if Ambari server is running
ambari_status=$(ambari-server status | grep "Ambari Server running")

if [ -z "$ambari_status" ]; then
    # Ambari server is not running
    print_red "Ambari server is not running."
    read -p "Do you want to start the Ambari server? (yes/no) " start_ambari
    if [ "$start_ambari" = "yes" ]; then
        # Start the Ambari server
        ambari-server start
        if [ $? -eq 0 ]; then
            print_green "Ambari server started successfully."
        else
            print_red "Failed to start Ambari server. Exiting."
            exit 1
        fi
    else
        print_yellow "Exiting without starting Ambari server."
        exit 1
    fi
else
    # Ambari server is already running
    print_green "Ambari server is already running."
fi

# Display the prompt for Spark3 service installation
read -p "Do you have Spark3 service installed in Ambari? (yes/no) " spark3_installed

# Check if Spark3 service is installed
if [[ "$spark3_installed" == "yes" ]]; then
    # Prompt the user for executing the backup script
    read -p "Did you execute generate_sql_backup_restore.sh script? (yes/no) " backup_executed
    # If the backup script is not executed, exit
    if [[ "$backup_executed" == "no" ]]; then
        print_red "Please execute the generate_sql_backup_restore.sh script and then rerun this script."
        exit 1
    fi
fi

# Continue with the Ambari upgrade process
print_green "Continuing with the Ambari upgrade process..."

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

# Function to install Ansible on RHEL 8
install_ansible_rhel8() {
    print_yellow "Enabling Ansible repository for RHEL 8..."
    sudo subscription-manager repos --enable ansible-2.9-for-rhel-8-x86_64-rpms
    print_yellow "Installing Ansible..."
    sudo yum install -y ansible
}

# Function to install Ansible on CentOS 7 and create inventory file
install_ansible_centos7() {
    print_yellow "Installing EPEL release and Ansible for CentOS 7..."
    sudo yum install -y epel-release
    sudo yum install -y ansible
}

# Check if Ansible is installed
if ! command -v ansible &> /dev/null
then
    print_yellow "Ansible is not installed. Installing now..."
    
    # Determine the OS version and install Ansible accordingly
    if grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
        if grep -q "release 8" /etc/redhat-release; then
            install_ansible_rhel8
            ansible_password="R#el@1+1=2"
        else
            print_red "Unsupported Red Hat version. Please install Ansible manually."
            exit 1
        fi
    elif grep -q "CentOS Linux release 7" /etc/redhat-release; then
        install_ansible_centos7
        ansible_password="Caps@Lock"
    else
        print_red "Unsupported OS version. Please install Ansible manually."
        exit 1
    fi
else
    print_green "Ansible is already installed."
    if grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
        if grep -q "release 8" /etc/redhat-release; then
            ansible_password="R#el@1+1=2"
        fi
    elif grep -q "CentOS Linux release 7" /etc/redhat-release; then
        ansible_password="Caps@Lock"
    fi
fi

# Check and configure host_key_checking in ansible.cfg
ANSIBLE_CFG="/etc/ansible/ansible.cfg"
if grep -q "^[^#]*host_key_checking" $ANSIBLE_CFG; then
    print_green "host_key_checking is already uncommented."
else
    print_yellow "Uncommenting host_key_checking in $ANSIBLE_CFG..."
    sudo sed -i 's/^#\(host_key_checking\)/\1/' $ANSIBLE_CFG
    print_green "host_key_checking has been uncommented."
fi

# Check and set deprecation_warnings in ansible.cfg
if grep -q "^[#]*deprecation_warnings" /etc/ansible/ansible.cfg; then
    print_yellow "Setting deprecation_warnings=False in /etc/ansible/ansible.cfg..."
    sudo sed -i 's/^[#]*deprecation_warnings.*/deprecation_warnings=False/' /etc/ansible/ansible.cfg
else
    print_yellow "Adding deprecation_warnings=False to /etc/ansible/ansible.cfg..."
    sudo sh -c "echo 'deprecation_warnings=False' >> /etc/ansible/ansible.cfg"
fi
print_green "deprecation_warnings is set to False in /etc/ansible/ansible.cfg"

# Retrieve the list of hosts from Ambari server
print_yellow "Retrieving the list of hosts from Ambari server..."
curl -s -u $AMBARI_API_USER:$AMBARI_API_PASS $AMBARI_API_URL | grep host_name | sed -n 's/.*"host_name" : "\([^\"]*\)".*/\1/p' > hostcluster.txt

# Verify hostcluster.txt is not empty
if [ ! -s hostcluster.txt ]; then
  print_red "Error: No hosts found in Ambari server."
  exit 1
fi

# Get the current hostname
CURRENT_HOSTNAME=$(hostname)

# Create Ansible inventory file
print_yellow "Creating Ansible inventory file..."
echo "[ambari_server]" > $INVENTORY_FILE
echo "$CURRENT_HOSTNAME ansible_host=$(hostname | awk '{print $1}') ansible_user=root ansible_password=\"$ansible_password\"" >> $INVENTORY_FILE

echo "[ambari_agents]" >> $INVENTORY_FILE
while read -r HOST; do
  echo "$HOST ansible_host=$(getent hosts $HOST | awk '{ print $2 }') ansible_user=root ansible_password=\"$ansible_password\"" >> $INVENTORY_FILE
done < hostcluster.txt

# Check and uninstall specified mpacks
#for MPACK in "${MPACKS[@]}"; do
#  if grep -qw $MPACK /var/lib/ambari-server/resources/mpacks/*/mpack.json; then
#    echo "Uninstalling mpack: $MPACK"
#    ambari-server uninstall-mpack --mpack-name=$MPACK
#  fi
#done

# Run the Ansible playbook
print_yellow "Running the Ansible playbook..."
ansible-playbook -i $INVENTORY_FILE ../ambari_upgrade.yml

# Check the status
if [ $? -eq 0 ]; then
  print_green "Ambari and ODP upgrade completed successfully."
else
  print_red "Error: Ambari and ODP upgrade failed."
  exit 1
fi
