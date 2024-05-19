# ambari_upgrade_acceldata


## 1. Ambari Service Configs backup and restore:

Execute:
https://github.com/bhagadepravin/ambari_upgrade_acceldata/blob/main/generate_sql_backup_restore.sh

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
