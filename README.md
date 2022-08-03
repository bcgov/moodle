# PSA Moodle for the BC Public Service Agency Learning Delivery

[![Lifecycle:Experimental](https://img.shields.io/badge/Lifecycle-Experimental-339999)]
# Moodle
---
title: Backup Container
description: A simple containerized backup solution for backing up one or more supported databases to a secondary location.


# Backup Container

[Backup Container] is a simple containerized backup solution for backing up one or more MYSQL databases used by the Moodle application to a secondary location. 
The backup containwer solution for this project is sourced from (https://github.com/BCDevOps/backup-container) and customized as per the Moodle application.

# Backup Container Options

1. You MUST use the recommended `backup.conf` configuration.
2. Within the `backup.conf`, you MUST specify the `DatabaseType` for each listed database.
3. You will need to create a build and deployment config for  backup container in use.
4. Mount the same `backup.conf` file (ConfigMap) to each deployed container.

## Backups in OpenShift

The Backup container for the moodle application is built using the template available below :
https://github.com/bcgov/moodle/blob/main/openshift/app/docker-build.yml

The Backup container for the moodle application is deployed using the template available at :
https://github.com/bcgov/moodle/blob/main/openshift/app/db-backup-deploy.yml


Following are the instructions for running the backups and a restore.

## Storage
The backup container uses two volumes, one for storing the backups and the other for restore/verification testing. The deployment template separates them intentionally.

### Backup Storage Volume

The recommended storage class for the backup volume for OCP4 is `netapp-file-backup`, backed up with the standard OCIO Backup infrastructure. Quota for this storage class is 25Gi by default. If you need more please put in a request for a quota change.

Simply create a PVC with the netapp-file-backup and mount it to your pod as you would any other PVC.

For additional details see the [DevHub](https://developer.gov.bc.ca/OCP4-Backup-and-Restore) page.

#### NFS Storage Backup and Retention Policy

NFS backed storage is covered by the following backup and retention policies:

- Backup
  - Daily: Incremental
  - Monthly: Full
- Retention
  - 90 days

### Restore/Verification Storage Volume

The default storage class for the restore/verification volume is `netapp-file-standard` (do not use `netapp-file-backup` as it is unsuitable for such transient workloads). The supplied deployment template will auto-provision this volume for you with it is published.

This volume should be large enough to host your largest database. Set the size by updating/overriding the `VERIFICATION_VOLUME_SIZE` value within the template.


## Deployment / Configuration

The following environment variables are defaults used by the `backup` app.

**NOTE**: These environment variables MUST MATCH those used by the database container(s) you are planning to backup.

| Name                       | Default (if not set) | Purpose                                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BACKUP_STRATEGY            | rolling              | To control the backup strategy used for backups. This is explained more below.                                                                                                                                                                                                                                                                                                |
| BACKUP_DIR                 | /backups/            | The directory under which backups will be stored. The deployment configuration mounts the persistent volume claim to this location when first deployed.                                                                                                                                                                                                                       |
| NUM_BACKUPS                | 31                   | Used for backward compatibility only, this value is used with the daily backup strategy to set the number of backups to retain before pruning.                                                                                                                                                                                                                                |
| DAILY_BACKUPS              | 6                    | When using the rolling backup strategy this value is used to determine the number of daily (Mon-Sat) backups to retain before pruning.                                                                                                                                                                                                                                        |
| WEEKLY_BACKUPS             | 4                    | When using the rolling backup strategy this value is used to determine the number of weekly (Sun) backups to retain before pruning.                                                                                                                                                                                                                                           |
| MONTHLY_BACKUPS            | 1                    | When using the rolling backup strategy this value is used to determine the number of monthly (last day of the month) backups to retain before pruning.                                                                                                                                                                                                                        |
| BACKUP_PERIOD              | 1d                   | Only used for Legacy Mode. Ignored when running in Cron Mode. The schedule on which to run the backups. The value is used by a sleep command and can be defined in d, h, m, or s.                                                                                                                                                                                             |
| DATABASE_SERVICE_NAME      | postgresql           | Used for backward compatibility only. The name of the service/host for the _default_ database target.                                                                                                                                                                                                                                                                         |
| DATABASE_USER_KEY_NAME     | database-user        | The database user key name stored in database deployment resources specified by DATABASE_DEPLOYMENT_NAME.                                                                                                                                                                                                                                                                     |
| DATABASE_PASSWORD_KEY_NAME | database-password    | The database password key name stored in database deployment resources specified by DATABASE_DEPLOYMENT_NAME.                                                                                                                                                                                                                                                                 |
| DATABASE_NAME              | my_postgres_db       | Used for backward compatibility only. The name of the _default_ database target; the name of the database you want to backup.                                                                                                                                                                                                                                                 |
| DATABASE_USER              | _wired to a secret_  | The username for the database(s) hosted by the database server. The deployment configuration makes the assumption you have your database credentials stored in secrets (which you should), and the key for the username is `database-user`. The name of the secret must be provided as the `DATABASE_DEPLOYMENT_NAME` parameter to the deployment configuration template.     |
| DATABASE_PASSWORD          | _wired to a secret_  | The password for the database(s) hosted by the database server. The deployment configuration makes the assumption you have your database credentials stored in secrets (which you should), and the key for the username is `database-password`. The name of the secret must be provided as the `DATABASE_DEPLOYMENT_NAME` parameter to the deployment configuration template. |
| FTP_URL                    |                      | The FTP server URL. If not specified, the FTP backup feature is disabled. The default value in the deployment configuration is an empty value - not specified.                                                                                                                                                                                                                |
| FTP_USER                   | _wired to a secret_  | The username for the FTP server. The deployment configuration creates a secret with the name specified in the FTP_SECRET_KEY parameter (default: `ftp-secret`). The key for the username is `ftp-user` and the value is an empty value by default.                                                                                                                            |
| FTP_PASSWORD               | _wired to a secret_  | The password for the FTP server. The deployment configuration creates a secret with the name specified in the FTP_SECRET_KEY parameter (default: `ftp-secret`). The key for the password is `ftp-password` and the value is an empty value by default.                                                                                                                        |
| WEBHOOK_URL                |                      | The URL of the webhook endpoint to use for notifications. If not specified, the webhook integration feature is disabled. The default value in the deployment configuration is an empty value - not specified.                                                                                                                                                                 |
| ENVIRONMENT_FRIENDLY_NAME  |                      | A friendly (human readable) name of the environment. This variable is used by the webhook integration to identify the environment from which the backup notifications originate. The default value in the deployment configuration is an empty value - not specified.                                                                                                         |
| ENVIRONMENT_NAME           |                      | A name or ID of the environment. This variable is used by the webhook integration to identify the environment from which the backup notifications originate. The default value in the deployment configuration is an empty value - not specified.                                                                                                                             |

### backup.conf

Using this default configuration you can easily back up a single postgres database, however we recommend you extend the configuration and use the `backup.conf` file to list a number of databases for backup and even set a cron schedule for the backups.

When using the `backup.conf` file the following environment variables are ignored, since you list all of your `host`/`database` pairs in the file; `DATABASE_SERVICE_NAME`, `DATABASE_NAME`. To provide the credentials needed for the listed databases you extend the deployment configuration to include `hostname_USER` and `hostname_PASSWORD` credential pairs which are wired to the appropriate secrets (where hostname matches the hostname/servicename, in all caps and underscores, of the database). For example, if you are backing up a database named `wallet-db/my_wallet`, you would have to extend the deployment configuration to include a `WALLET_DB_USER` and `WALLET_DB_PASSWORD` credential pair, wired to the appropriate secrets, to access the database(s) on the `wallet-db` server.

### Cron Mode

The `backup` container supports running the backups on a cron schedule. The schedule is specified in the `backup.conf` file. Refer to the [backup.conf](./config/backup.conf) file for additional details and examples.

### Resources

The backup-container is assigned with `Best-effort` resource type (setting zero for request and limit), which allows the resources to scale up and down without an explicit limit as resource on the node allow. It benefits from large bursts of recourses for short periods of time to get things more quickly. After some time of running the backup-container, you could then set the request and limit according to the average resource consumption.

## Multiple Databases

When backing up multiple databases, the retention settings apply to each database individually. For instance if you use the `daily` strategy and set the retention number(s) to 5, you will retain 5 copies of each database. So plan your backup storage accordingly.

## Backup Strategies

The `backup` app supports two backup strategies, each are explained below. Regardless of the strategy backups are identified using a core name derived from the `host/database` specification and a timestamp. All backups are compressed using gzip.

### Daily

The daily backup strategy is very simple. Backups are created in dated folders under the top level `/backups/` folder. When the maximum number of backups (`NUM_BACKUPS`) is exceeded, the oldest ones are pruned from disk.

For example (faked):

```
================================================================================================================================
Current Backups:
--------------------------------------------------------------------------------------------------------------------------------
1.0K    2018-10-03 22:16        ./backups/2018-10-03/postgresql-TheOrgBook_Database_2018-10-03_22-16-11.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/postgresql-TheOrgBook_Database_2018-10-03_22-16-28.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/postgresql-TheOrgBook_Database_2018-10-03_22-16-46.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_holder_2018-10-03_22-16-13.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_holder_2018-10-03_22-16-31.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_holder_2018-10-03_22-16-48.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_verifier_2018-10-03_22-16-08.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_verifier_2018-10-03_22-16-25.sql.gz
1.0K    2018-10-03 22:16        ./backups/2018-10-03/wallet-db-tob_verifier_2018-10-03_22-16-43.sql.gz
13K     2018-10-03 22:16        ./backups/2018-10-03
...
61K     2018-10-04 10:43        ./backups/
================================================================================================================================
```

### Rolling

The rolling backup strategy provides a bit more flexibility. It allows you to keep a number of recent `daily` backups, a number of `weekly` backups, and a number of `monthly` backups.

- Daily backups are any backups done Monday through Saturday.
- Weekly backups are any backups done at the end of the week, which we're calling Sunday.
- Monthly backups are any backups done on the last day of a month.

There are retention settings you can set for each. The defaults provide you with a week's worth of `daily` backups, a month's worth of `weekly` backups, and a single backup for the previous month.

Although the example does not show any `weekly` or `monthly` backups, you can see from the example that the folders are further broken down into the backup type.

For example (faked):

```
================================================================================================================================
Current Backups:
--------------------------------------------------------------------------------------------------------------------------------
0       2018-10-03 22:16        ./backups/daily/2018-10-03
1.0K    2018-10-04 09:29        ./backups/daily/2018-10-04/postgresql-TheOrgBook_Database_2018-10-04_09-29-52.sql.gz
1.0K    2018-10-04 10:37        ./backups/daily/2018-10-04/postgresql-TheOrgBook_Database_2018-10-04_10-37-15.sql.gz
1.0K    2018-10-04 09:29        ./backups/daily/2018-10-04/wallet-db-tob_holder_2018-10-04_09-29-55.sql.gz
1.0K    2018-10-04 10:37        ./backups/daily/2018-10-04/wallet-db-tob_holder_2018-10-04_10-37-18.sql.gz
1.0K    2018-10-04 09:29        ./backups/daily/2018-10-04/wallet-db-tob_verifier_2018-10-04_09-29-49.sql.gz
1.0K    2018-10-04 10:37        ./backups/daily/2018-10-04/wallet-db-tob_verifier_2018-10-04_10-37-12.sql.gz
22K     2018-10-04 10:43        ./backups/daily/2018-10-04
22K     2018-10-04 10:43        ./backups/daily
4.0K    2018-10-03 22:16        ./backups/monthly/2018-10-03
4.0K    2018-10-03 22:16        ./backups/monthly
4.0K    2018-10-03 22:16        ./backups/weekly/2018-10-03
4.0K    2018-10-03 22:16        ./backups/weekly
61K     2018-10-04 10:43        ./backups/
================================================================================================================================
```

## Using the Backup Script

The [backup script](./docker/backup.sh) has a few utility features built into it. For a full list of features and documentation run `backup.sh -h`.

Features include:

- The ability to list the existing backups, `backup.sh -l`
- Listing the current configuration, `backup.sh -c`
- Running a single backup cycle, `backup.sh -1`
- Restoring a database from backup, `backup.sh -r <databaseSpec/> [-f <backupFileFilter>]`
  - Restore mode will allow you to restore a database to a different location (host, and/or database name) provided it can contact the host and you can provide the appropriate credentials.
- Verifying backups, `backup.sh [-s] -v <databaseSpec/> [-f <backupFileFilter>]`
  - Verify mode will restore a backup to the local server to ensure it can be restored without error. Once restored a table query is performed to ensure there was at least one table restored and queries against the database succeed without error. All database files and configuration are destroyed following the tests.

## Using Backup Verification

The [backup script](./docker/backup.sh) supports running manual or scheduled verifications on your backups; `backup.sh [-s] -v <databaseSpec/> [-f <backupFileFilter>]`. Refer to the script documentation `backup.sh -h`, and the configuration documentation, [backup.conf](config/backup.conf), for additional details on how to use this feature.


## Backup

The purpose of the backup app is to do automatic backups. Deploy the Backup app to do daily backups. Viewing the Logs for the Backup App will show a record of backups that have been completed.

The Backup app performs the following sequence of operations:

1. Create a directory that will be used to store the backup.
2. Use the `pg_dump` and `gzip` commands to make a backup.
3. Cull backups more than $NUM_BACKUPS (default 31 - configured in deployment script)
4. Wait/Sleep for a period of time and repeat

A separate pod is used vs. having the backups run from the Postgres Pod for fault tolerant purposes - to keep the backups separate from the database storage. We don't want to, for example, lose the storage of the database, or have the database and backups storage fill up, and lose both the database and the backups.

### Immediate Backup:

#### Execute a single backup cycle with the pod deployment

- Check the logs of the Backup pod to make sure a backup isn't run right now (pretty unlikely...)
- Open a terminal window to the pod
- Run `backup.sh -1`
  - This will run a single backup cycle and exit.

### Restore

The `backup.sh` script's restore mode makes it very simple to restore the most recent backup of a particular database. It's as simple as running a the following command, for example (run `backup.sh -h` for full details on additional options);

    backup.sh -r postgresql/TheOrgBook_Database

Following are more detailed steps to perform a restore of a backup.

1. Log into the OpenShift Console and log into OpenShift on the command shell window.
   1. The instructions here use a mix of the console and command line, but all could be done from a command shell using "oc" commands.
1. Scale to 0 all Apps that use the database connection.
   1. This is necessary as the Apps will need to restart to pull data from the restored backup.
   1. It is recommended that you also scale down to 0 your client application so that users know the application is unavailable while the database restore is underway.
      1. A nice addition to this would be a user-friendly "This application is offline" message - not yet implemented.
1. Restart the database pod as a quick way of closing any other database connections from users using port forward or that have rsh'd to directly connect to the database.
1. Open an rsh into the backup pod:
   1. Open a command prompt connection to OpenShift using `oc login` with parameters appropriate for your OpenShift host.
   1. Change to the OpenShift project containing the Backup App `oc project <Project Name>`
   1. List pods using `oc get pods`
   1. Open a remote shell connection to the **backup** pod. `oc rsh <Backup Pod Name>`
1. In the rsh run the backup script in restore mode, `./backup.sh -r <DatabaseSpec/>`, to restore the desired backup file. For full information on how to use restore mode, refer to the script documentation, `./backup.sh -h`. Have the Admin password for the database handy, the script will ask for it during the restore process.
   1. The restore script will automatically grant the database user access to the restored database. If there are other users needing access to the database, such as the DBA group, you will need to additionally run the following commands on the database pod itself using `psql`:
      1. Get a list of the users by running the command `\du`
      1. For each user that is not "postgres" and $POSTGRESQL_USER, execute the command `GRANT SELECT ON ALL TABLES IN SCHEMA public TO "<name of user>";`
   1. If users have been set up with other grants, set them up as well.
1. Verify that the database restore worked
   1. On the database pod, query a table - e.g the USER table: `SELECT * FROM "SBI_USER";` - you can look at other tables if you want.
   1. Verify the expected data is shown.
1. Exit remote shells back to your local command line
1. From the Openshift Console restart the app:
   1. Scale up any pods you scaled down and wait for them to finish starting up. View the logs to verify there were no startup issues.
1. Verify full application functionality.

Done!

## Network Policies

The default `backup-container` template contains a basic Network Policy that is designed to be functioning out-of-the-box for most standard deployments. It provides:
- Internal traffic authorization towards target databases: for this to work, the target database deployments must be in the same namespace/environment AND must be labelled with `backup=true`.

The default Network Policy is meant to be a "one size fits all" starter policy to facilitate standing up the `backup-container` in a new environment. Please consider updating/tweaking it to better fit your needs, depending on your setup.



