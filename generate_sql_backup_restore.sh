#!/bin/bash

# Variables
MPACKS=("ambari-impala-mpack" "httpfs-ambari-mpack" "hue-ambari.mpack" "nifi-ambari-mpack" "spark3-ambari-3.2.2.mpack" "spark3-ambari-3.2.2-3.2.2.0-1.mpack")
SERVICES=("IMPALA" "HTTPFS" "HUE" "NIFI" "SPARK3" "SPARK3")
BACKUP_DIR="pre_upgrade"
RESTORE_DIR="post_upgrade"
DB_NAME="service_conf_bck"
LOG_FILE="upgrade_script.log"
VERBOSE=1

# Function to log messages
log() {
    local MESSAGE=$1
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" | tee -a $LOG_FILE
}

# Function to check command success
check_command() {
    local COMMAND=$1
    if ! $COMMAND; then
        log "Command failed: $COMMAND"
        exit 1
    fi
}

# Function to create directories
create_directories() {
    check_command "mkdir -p $BACKUP_DIR"
    check_command "mkdir -p $RESTORE_DIR"
}

# Function to create backup SQL
create_backup_sql() {
    BACKUP_SQL="$BACKUP_DIR/backup_configs.sql"
    echo "create database if not exists $DB_NAME;" > $BACKUP_SQL
    echo "use $DB_NAME;" >> $BACKUP_SQL
}

# Function to create restore SQL for a service
create_restore_sql() {
    local SERVICE=$1
    RESTORE_SQL="$RESTORE_DIR/restore_${SERVICE}.sql"
    LATEST_VERSION="(SELECT MAX(version) FROM $DB_NAME.configs_prior_patch WHERE service_name = '$SERVICE')"
    echo "use ambari;" > $RESTORE_SQL
    echo "update clusterconfig a set config_data = (select config_data from $DB_NAME.configs_prior_patch b where a.type_name = b.type_name and version = $LATEST_VERSION and service_name = '$SERVICE')," >> $RESTORE_SQL
    echo "config_attributes = (select config_attributes from $DB_NAME.configs_prior_patch b where a.type_name = b.type_name and version = $LATEST_VERSION and service_name = '$SERVICE')" >> $RESTORE_SQL
    echo "where config_id in (select config_id from serviceconfigmapping where service_config_id in (select service_config_id from serviceconfig where service_name = '$SERVICE' and version = (select max(version) from serviceconfig where service_name = '$SERVICE')));" >> $RESTORE_SQL
}

# Function to append service names to backup SQL
append_service_names_to_backup_sql() {
    local INSTALLED_SERVICES=("$@")
    SERVICE_NAMES=$(IFS=,; echo "${INSTALLED_SERVICES[*]}")
    echo "CREATE TABLE IF NOT EXISTS configs_prior_patch AS SELECT cc.config_id, cc.type_name, cc.config_data, cc.config_attributes, service_name, sc.version, sc.note, (SELECT MAX(version) FROM ambari.serviceconfig s WHERE s.service_name = sc.service_name) AS max_version FROM ambari.serviceconfig sc INNER JOIN ambari.serviceconfigmapping scm ON sc.service_config_id = scm.service_config_id INNER JOIN ambari.clusterconfig cc ON cc.config_id = scm.config_id WHERE sc.service_name IN ($SERVICE_NAMES);" >> $BACKUP_SQL
}

# Function to identify installed mpacks and map to services
identify_installed_services() {
    local INSTALLED_SERVICES=()
    for i in "${!MPACKS[@]}"; do
        if grep -qw "${MPACKS[$i]}" /var/lib/ambari-server/resources/mpacks/*/mpack.json; then
            SERVICE="${SERVICES[$i]}"
            if [[ ! " ${INSTALLED_SERVICES[*]} " =~ " '$SERVICE' " ]]; then
                INSTALLED_SERVICES+=("'$SERVICE'")
            fi
            log "Adding service $SERVICE to backup and restore scripts."
            create_restore_sql "$SERVICE"
        fi
    done
    append_service_names_to_backup_sql "${INSTALLED_SERVICES[@]}"
}

# Main function to orchestrate the script
main() {
    create_directories
    create_backup_sql
    identify_installed_services
    log "Backup and restore SQL files have been created in $BACKUP_DIR and $RESTORE_DIR."
    
    # Verbose output
    if [ $VERBOSE -eq 1 ]; then
        log "Installed services: ${INSTALLED_SERVICES[*]}"
        log "Backup SQL file: $BACKUP_SQL"
        for SERVICE in "${INSTALLED_SERVICES[@]}"; do
            log "Restore SQL file for $SERVICE: $RESTORE_DIR/restore_${SERVICE}.sql"
        done
    fi
}

# Run main function
main
