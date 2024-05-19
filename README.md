# Acceldata Ambari Upgrade Steps:-


## 1. Ambari Service Configs backup and restore:

-  [generate_sql_backup_restore.sh](https://github.com/bhagadepravin/ambari_upgrade_acceldata/blob/main/generate_sql_backup_restore.sh)

1. **Navigate to the directory containing the generated SQL script**:
   ```bash
   cd pre_upgrade
   ```

2. **Launch the MySQL client**:
   ```bash
   mysql -u root -p
   ```

3. **When prompted, enter your MySQL root password** (`admin123` in your case`).

4. **Select the appropriate database**:
   ```sql
   use service_conf_bck;
   ```

5. **Source the SQL script**:
   ```sql
   source backup_configs.sql;
   ```

6. **Exit the MySQL client**:
   ```sql
   exit;
   ```

This will execute the SQL commands contained in `backup_configs.sql` within the `service_conf_bck` database in MySQL. Make sure to replace `admin123` with your actual MySQL root password, and adjust the database name if necessary.

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
