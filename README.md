# Acceldata Ambari Upgrade Steps:-

`git clone https://github.com/bhagadepravin/ambari_upgrade_acceldata.git`

## 1. Service Configuration Backup before upgrade and Restore after update
Currently Supports, HUE, Impala, Ranger, Ranger KMS, Spark3
```
https://github.com/bhagadepravin/ambari_upgrade_acceldata/blob/main/config_backup_restore.sh

bash config_backup_restore.sh
```

## 2. Update ambari_upgrade.yml

-  [ambari_upgrade.yml](https://github.com/bhagadepravin/ambari_upgrade_acceldata/blob/main/ambari_upgrade.yml)

 - Update "ambari_version" , odp_version, Ambari and ODP repo, Database details.

## 3. Execute ambari_upgrade.sh

-  [ambari_upgrade.sh](https://github.com/bhagadepravin/ambari_upgrade_acceldata/blob/main/ambari_upgrade.sh)

Here's a Bash script that automates the setup and execution of the Ansible playbook for upgrading Ambari and ODP. This script performs the following tasks:

1. Creates a directory for the upgrade process.
2. Installs Ansible.
3. Sets up passwordless SSH using a provided script.
4. Retrieves the list of hosts from the Ambari server.
5. Creates the Ansible inventory file.
6. Runs the Ansible playbook for the upgrade.

### Steps to Use the Script

1. **Save the Script**: Save the above script to a file, e.g., `ambari_upgrade.sh`.
2. **Make the Script Executable**:
   ```sh
   chmod +x ambari_upgrade.sh
   ```
3. **Run the Script**:
   ```sh
   ./ambari_upgrade.sh
   ```

This script automates the entire process of setting up and running the Ansible playbook to upgrade Ambari and ODP, making it easier and faster to manage the upgrade process across multiple nodes.
