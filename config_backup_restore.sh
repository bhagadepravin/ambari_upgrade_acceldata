#!/bin/bash

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display messages in green color
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to display messages in yellow color
print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to display messages in red color
print_error() {
    echo -e "${RED}$1${NC}"
}

# Set Ambari server details
export AMBARISERVER=$(hostname -f)
export USER=admin
export PASSWORD=admin
export PORT=8080
export PROTOCOL=http

# Function to retrieve cluster name from Ambari
get_cluster_name() {
    local cluster=$(curl -s -k -u "$USER:$PASSWORD" -i -H 'X-Requested-By: ambari' "$PROTOCOL://$AMBARISERVER:$PORT/api/v1/clusters" | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')
    echo "$cluster"
}

# Display script information and usage instructions
print_script_info() {
    echo -e "${GREEN}Ambari Ranger Config Backup and Restore Script${NC}"
    echo -e "This script allows you to backup and restore Ranger configurations in Ambari."
    echo -e "Please ensure that you have set all necessary variables correctly before proceeding."
    echo -e "Usage: ./ranger_config_backup_restore.sh"
}

# Prompt user to confirm actions
confirm_action() {
    local action="$1"
    read -p "Are you sure you want to $action? (yes/no): " choice
    case "$choice" in 
        [yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to backup Ranger configurations
backup_ranger_configs() {
    local backup_dir="upgrade_backup"
    mkdir -p "$backup_dir"
    echo -e "Backing up Ranger configurations..."
    for config in "${RANGER_CONFIGS[@]}"; do
        print_warning "Backing up configuration: $config"
        python /var/lib/ambari-server/resources/scripts/configs.py \
            -u "$USER" -p "$PASSWORD" -s "$PROTOCOL" -a get -t "$PORT" -l "$AMBARISERVER" -n "$CLUSTER" \
            -c "$config" -f "$backup_dir/$config.json" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_success "Backup of $config completed successfully."
        else
            print_error "Failed to backup $config. Please check logs for details."
        fi
    done
    print_success "Backup process completed. Configurations are saved in $backup_dir"
}

# Function to restore Ranger configurations
restore_ranger_configs() {
    local backup_dir="upgrade_backup"
    echo -e "Restoring Ranger configurations..."
    for config in "${RANGER_CONFIGS[@]}"; do
        print_warning "Restoring configuration: $config"
        python /var/lib/ambari-server/resources/scripts/configs.py \
            -u "$USER" -p "$PASSWORD" -s "$PROTOCOL" -a set -t "$PORT" -l "$AMBARISERVER" -n "$CLUSTER" \
            -c "$config" -f "$backup_dir/$config.json" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_success "Restore of $config completed successfully."
        else
            print_error "Failed to restore $config. Please check logs for details."
        fi
    done
    print_success "Restore process completed."
}

# Main function
main() {
    print_script_info
    CLUSTER=$(get_cluster_name)
    RANGER_CONFIGS=(
        "admin-properties"
        "atlas-tagsync-ssl"
        "ranger-solr-configuration"
        "ranger-tagsync-policymgr-ssl"
        "ranger-tagsync-site"
        "tagsync-application-properties"
        "ranger-ugsync-site"
        "ranger-env"
        "ranger-admin-site"
    )
    PS3="Select an option: "
    select option in "Backup Ranger Configurations" "Restore Ranger Configurations" "Exit"; do
        case $REPLY in
            1) 
                if confirm_action "backup Ranger configurations"; then
                    backup_ranger_configs
                fi
                ;;
            2)
                if confirm_action "restore Ranger configurations"; then
                    restore_ranger_configs
                fi
                ;;
            3) 
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid option. Please select a valid option."
                ;;
        esac
    done
}

# Run main function
main
