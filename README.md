## How to extract an official MariaDB mysqldump and mysql binary from a Docker container that will work on our cflinuxfs2 container image

```
$ docker pull mariadb
$ docker run --name some-mariadb -e MYSQL_ROOT_PASSWORD=password -d mariadb -it bash
$ docker cp 29a9060d5387:/usr/bin/mysqldump .
```

cf push si-dumper -b binary_buildpack -c "./do-nothing.sh" --health-check-type none

## Prove that you can run a task
cf run-task si-dumper "./dump.sh" --name "trial-dump"

## Bind the app to a DB
cf create-service p-mysql 100mb dumper-dev
cf bind-service si-dumper dumper-dev

cf mysql dumper-dev
create table stuff (id int auto_increment not null primary key, stuff TEXT) ;
insert into stuff values (null, "hello world") ;

## Schedule to back up periodically
cf create-service scheduler-for-pcf standard si-backup-scheduler
cf bind-service si-dumper si-backup-scheduler
cf restage si-dumper

Download and install the scheduler CLI plugin from https://network.pivotal.io/products/p-scheduler/
cf install-plugin ~/Downloads/scheduler-for-pcf-cliplugin-macosx64-binary-1.1.0

cf create-job si-dumper periodic-upload "./dump2.sh"

Prove that you can run the job once, and take timings for how long it'll take:
> cf logs si-dumper
> cf run-job periodic-upload

And schedule backups to run twice per hour:

```
$ cf schedule-job periodic-upload "0,30 * * * ?"
Scheduling job periodic-upload for si-dumper to execute based on expression 0,30 * * * ? in org moragasystems / space dev as mnicosia@pivotal.io
OK
```
