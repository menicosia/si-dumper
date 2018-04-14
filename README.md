# si-dumper

Dump and restore MySQL service instances on Cloud Foundry.

A minimal implementation to automatically dump an MySQL service instance to Amazon S3, (and optionally) restore to a different service instance, possibly on a totally separate foundation.

**Benefits**
- Dev-initiated, no Operator required
- Minimal footprint
  - Runs on the platform as Diego tasks
  - Zero long-running application instances
  - No dependence on `cf ssh` nor `cf mysql`
- Periodic, reliable backups **and restores**
  - Runs on an **automatic schedule** when combined with PCF Scheduler

**si-dumper** uses Amazon AWS S3 as an intermediate location to store backup artifacts. Since **si dumper** is implemented as three simple scripts, **you can easily modify it** to use whatever storage medium works best for you. Some alternate options might be via SCP or a WebDAV server.

**Motivation**

When running `cf-mysql-release` as a service, all service instances are stored within a single MariaDB cluster. There is no facility for a Developer to automatically back up a service instance according to their own schedule. Where available, backups are run across all service instances, and available only to the Operator.

**si-dumper** makes it easy for a Developer to set up automated backups of their service instance, so that they can be assured that they have access to historical copies of their data.

Additionally, there is no provision for automatic restore of a single service instance. **si-dumper** splits dump and restore into separate tasks, so you can run a restore task anywhere.

**si-dumper** leverages features of Cloud Foundry to make backup and restore lightweight and easy!

## Prerequisites

- You **must** have cf CLI v6.36.1 or greater.
- You **must** extract the `mysql` and `mysqldump` binaries from MariaDB.

## PART 1: Automated Backups

### Step 1: Retrieve MariaDB binaries

You'll need two mysql binaries to interact with `cf-mysql-release`. These cannot be distributed with **si-dumper**, but it's easy to retrieve them yourself.

Extract the official MariaDB `mysqldump` and `mysql` binaries from a Docker container that will work on our cflinuxfs2 container image.
  - If you're on Linux, you can probably use `apt-get` or `yum` install MariaDB 10.1.

```
$ git clone [this repo]
$ cd si-dumper
$ docker pull mariadb:10.1
$ docker run --name some-mariadb -e MYSQL_ROOT_PASSWORD=password -d mariadb -it bash
$ docker ps -a
[find the id of your MariaDB container]
$ docker cp YOUR-CONTAINER-ID:/usr/bin/mysqldump .
```

### Step 2: Create backup artifacts

(optional) Create some data:
```
$ cf marketplace -s p-mysql
$ cf create-service p-mysql P-MYSQL-PLAN dumperDB
$ cf mysql dumperDB
MariaDB [cf_abc]> create table stuff (id int auto_increment not null primary key, stuff TEXT) ;
MariaDB [cf_abc]> insert into stuff values (null, "hello world") ;
```

Push the dumper app, zero instances:

```
$ cf push si-dumper -b binary_buildpack -i 0
$ cf set-env si-dumper s3Bucket YOUR-BUCKET
$ cf set-env si-dumper s3AccessKey "XXX"
$ cf set-env si-dumper s3SecretKey 'XXX'
```

Bind the app to a service instance:
```
$ cf bind-service si-dumper dumperDB
$ cf restage si-dumper
```

Create a backup artifact:

```
$ cf run-task si-dumper "./dump.sh" --name "try-dumping"
```

... and you're done! You can review the logs to get a sense of how long each backup task will take at your current data volume:

```
$ cf logs si-dumper --recent
```

### Step 3: (optional) Schedule to back up periodically

If you have access to [PCF Scheduler](https://docs.pivotal.io/pcf-scheduler/) you can use it to periodically launch backup tasks.

Download and install the scheduler CLI plugin from https://network.pivotal.io/products/p-scheduler/:

```
$ cf install-plugin ~/Downloads/scheduler-for-pcf-cliplugin-macosx64-binary-1.1.0
```
- Download and use the correct plugin for the computer that you'll run the `cf` CLI.

Create and bind an instance of the scheduler to the **si-dumper** app:

```
$ cf marketplace -s scheduler-for-pcf
$ cf create-service scheduler-for-pcf SCHEDULER-PLAN si-backup-scheduler
$ cf bind-service si-dumper si-backup-scheduler
$ cf restage si-dumper
$ cf create-job si-dumper periodic-upload "./dump.sh"
```

Dry run:
```
$ cf run-job periodic-upload
```

And schedule backups to run twice per hour:

```
$ cf schedule-job periodic-upload "0,30 * * * ?"
Scheduling job periodic-upload for si-dumper to execute based on expression 0,30 * * * ? in org moragasystems / space dev as mnicosia@pivotal.io
OK
```

## PART 2: Automated restore

Create and configure a target for continuous restore:
```
$ cf marketplace -s p-mysql
$ cf create-service p-mysql P-MYSQL-PLAN load-targetDB
$ cf set-env si-loader s3Bucket YOUR-BUCKET
$ cf set-env si-loader s3AccessKey "XXX"
$ cf set-env si-loader s3SecretKey 'XXX'
$ cf bind-service si-loader load-targetDB
$ cf push si-loader -b binary_buildpack -i 0
```
- This service instance can be **anywhere in the world** that can access AWS S3. It **does not need** to be the same foundation which hosts the database that is being backed up.
- If you intend to use PCF Scheduler, as above, to implement **continuous restore**, you must create the service instance in a different space than the source database.

Prove there's no data in `load-targetDB`:
```
$ cf mysql load-targetDB

MariaDB [cf_abc]> show tables ;
Empty set (0.08 sec)
```

**Restore from most recent backup artifact**

```
$ cf run-task si-loader "./restore.sh" --name "try-restore"
$ cf mysql load-targetDB
MariaDB [cf_abc]> select * from stuff ;
+----+-------------+
| id | stuff       |
+----+-------------+
|  4 | hello world |
+----+-------------+
```
