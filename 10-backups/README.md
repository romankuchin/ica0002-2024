# Lab 10

In this lab we will set up automatic backups for your infrastructure and improve the documentation
from [the previous lab](../09-backups) accordingly.

There are multiple ways how to do backups; on this lab we'll use probably the simplest approach:
 1. Gather data to be backed up from certain services to a single location on this machine
 2. Upload all this data to the backup server
 3. Document the service restore process


## Task 1

Update `mysql` role: ensure that `/home/backup/mysql` directory is created on MySQL servers, owned
and writeable by user `backup`.

Update `influxdb` role: ensure that `/home/backup/influxdb` directory is created on InfluxDB
servers, owned and writeable by  user `backup`.

Update `init` role:
 - ensure `/home/backup/restore` directory is created, owned and writeable by user `backup`
 - ensure [Duplicity](https://duplicity.gitlab.io) is installed; the package is available in the
   Ubuntu APT repository


## Task 2

Update `mysql` role to configure MySQL access for a `backup` user created in the
[lab 9](../09-backups); we will need:
 - MySQL user named `backup` with privileges `LOCK TABLES,SELECT` on `agama` database
 - MySQL client configuration file `/home/backup/.my.cnf`

**Make sure that this `.my.cnf` file is readable only by user `backup` and noone else!**

Hint: you did something very similar for Prometheus MySQL exporter user in the
[lab 7](../07-grafana). But be careful: `backup` and `exporter` users have different `.my.cnf`
files!

Note that this setup is slightly different from what was shown in the demo on the lecture:
 - in the demo user `backup` could drop and create the tables, for simplicity
 - in your setup user `backup` can only _read_ the data but not _write_; restores are expected to be
   done by user `root`

Ensure that user `backup` can create MySQL dumps; run this command manually on your MySQL host:

    sudo -u backup mysqldump agama >/dev/null; echo $?

This should print no errors; exit code (`$?`) should be 0; example:

    0

You may get errors like this when running the command above:

    mysqldump: Error: 'Access denied; you need (at least one of) the PROCESS privilege(s)
    for this operation' when trying to dump tablespaces

Simplest fix is to exclude tablespaces from the dump; add this to `/home/backup/.my.cnf` file:

    [mysqldump]
    no_tablespaces

and try making a dump again. There should be no errors printed now.


## Task 3

Uppdate `mysql` role to schedule MySQL dumps with Cron. For that, ensure that
`/etc/cron.d/mysql-backup` file is created -- this file is called "Cron tab".

This Cron tab file content is

    x x x x x  backup  <command>

    ^          ^       ^
    |          |       |
    schedule   |       the command itself
               |
               user that runs the command

Replace `x x x x x` with the schedule you defined in the `backup_sla.md` (lab 9). Feel free to
update `backup_sla.md` if you feel that schedule defined there is not quite right. You can use
https://crontab.guru/ to check your schedule format.

Note: make sure that backups are completed by 01:00 UTC / 03:00 EET. All virtual machines on this
course are destroyed around at that time every night.

Use this command for MySQL dumps:

    mysqldump agama > /home/backup/mysql/agama.sql

Note that only `agama` database is backed up; you can safely skip other databases.

Apply your changes with

    ansible-playbook infra.yaml

Use this commands to check that dump was created as scheduled (note the file modification times):

    ls -la /home/backup/mysql

Hint: _for testing period_ you can temporary change the Cron schedule to run the dumps earlier, for
example, use `45 10 * * *` if it's 10:42 now, so you can check if it works and see the results
faster.

**Make sure to change this back to what is defined in `backup_sla.md` once testing is finished!**

**Remember that server time zone is UTC!** If _your_ clock shows 10:42 (Estonian time), server
clock shows 8:42 at the same time. Run `date` command on server and check https://time.is/UTC if
unsure.

Check if you can restore the backup; run this on managed host as user `root` (not `backup`; `root`
can write data to MySQL but `backup` user can only read):

    mysql agama < /home/backup/mysql/agama.sql

Make sure that service is up and running and contains all the data from the backup.


## Task 4

Update `/etc/cron.d/mysql-backup` Cron tab and add the backup upload jobs. Backups should be
uploaded to the directory called `mysql` on the backup server; this directory is pre-created for
your user.

Example for user `elvis`, Duplicity running over Rsync, weekly full and daily incremental backups
uploaded to `/home/elvis/mysql` directory on the backups server -- your file will look similar but
schedules will probably be different:

    12 0 * * 0  backup  duplicity --no-encryption full /home/backup/mysql/ rsync://elvis@backup.x.y/mysql
    12 0 * * 1-6  backup  duplicity --no-encryption incremental /home/backup/mysql/ rsync://elvis@backup.x.y/mysql

Make sure that whichever schedule you choose the first created backup is full -- not incremental.
You might need to create the first full backup yourself -- just run the command from the Cron tab
manually on the managed host as user `backup`.

Make sure that Duplicity is scheduled to run after local MySQL dump is finished -- not before, not
at the same time!

It is okay to skip the backup encryption **for this lab**. But remember --
**backups should be encrypted in the production systems!**


## Task 5

Once Duplicity creates its first backup make sure you can restore the service from it. For that,
download the backup to the managed host and try restoring the service.

Example command (update it as needed) to download the backup, run on the managed host as user
`backup`:

    duplicity --no-encryption restore rsync://elvis@backup.x.y/mysql /home/backup/restore/mysql

Example command to restore the backup can be found in the task 3. Make sure to restore from
`/home/backup/restore` this time, **not** from `/home/backup/mysql`!

Create a free text file named `backup_restore.md` and describe the detailed process of MySQL backup
restore (what commands to run, as which user, how to verify the result etc.). Restore can be a
manual process, no need to automate it with Ansible. For example,

    Install and configure infrastructure with Ansible:

        ansible-playbook infra.yaml

    Restore MySQL data from the backup:

        sudo -u backup duplicity --no-encryption restore <args>
        <another-command>
        <yet-another-command>

    <add a few words here how the result of backup restore can be checked>

Target audience for this document is someone who has root access to the managed host but who is
**not** familiar with your service setup. In real life it would be your colleague who will be
restoring the service from the backup if you are not available to do it.

For this lab you can treat the teachers as target audience -- we should be able to restore your
service having only your GitHub repository (that also contains backup restore document) and the
backups, without asking you a single question.

Make sure to verify these instructions, i. e. each service should be restorable by running the
commands you documented.

Run the restore procedure **at least twice** -- first run won't reveal all the possible problems.


## Task 6

Set up InfluxDB backups similarly as you did for MySQL, and add corresponding section to
`backup_restore.md`.

There are a few differences in case of InfluxDB:
 - Ansible role is be named `influxdb`
 - Cron tab file should be named `/etc/cron.d/influxdb-backup`
 - dump and restore procedures are different
 - backup should be uploaded to the directory called `influxdb`

InfluxDB has native dump tool; you can find more details here:
https://docs.influxdata.com/influxdb/v1/administration/backup_and_restore/.

Ensure that user `backup` can create InfluxDB dumps; run this command manually on your InfluxDB
host:

    sudo -u backup influxd backup -portable -db telegraf /tmp; echo $?

This should print no errors; exit code should be 0; example:

    2024/11/02 14:41:48 backing up metastore to /tmp/meta.00
    2024/11/02 14:41:48 backing up db=telegraf
    2024/11/02 14:41:48 backing up db=telegraf rp=autogen shard=2 to /tmp/telegraf.autogen.00002.00 since 0001-01-01T00:00:00Z
    2024/11/02 14:41:49 backup complete:
    2024/11/02 14:41:49 	/tmp/20241102T144148Z.meta
    2024/11/02 14:41:49 	/tmp/20241102T144148Z.s2.tar.gz
    2024/11/02 14:41:49 	/tmp/20241102T144148Z.manifest
    0

Use this command in Cron tab to create InfluxDB dumps; remember that is should be run by user
`backup`, not `root`:

    rm -rf /home/backup/influxdb/*; influxd backup -portable -db telegraf /home/backup/influxdb

Here the previous dump is deleted before creating a new one.

Note that only `telegraf` database is backed up; you can safely skip other databases.

Downloading backup can be done with pretty much the same command as for MySQL -- just modify it to
download the InfluxDB backup instead.

To restore the backup you will need to delete existing `telegraf` database first. It also makes
sense to stop the Telegraf service so that it doesn't recreate the database before you could
restore it:

    sudo -u backup duplicity --no-encryption restore <args>
    service telegraf stop
    influx -execute 'DROP DATABASE telegraf'
    influxd restore -portable -db telegraf /home/backup/restore/influxdb

After you have verified that backup was restore successfully, run

    ansible-playbook infra.yaml

to start the Telegraf service.

Run the restore procedure **at least twice** -- first run won't reveal all the possible problems.

Update the `backup_restore.md` file with the exact restore instructions for InfluxDB.


## Task 7

Add backup monitoring to Grafana.

Our backup server exposes backup metrics that should be collected by your Prometheus and displayed
in your Grafana.

You can view the metrics by running `curl http://backup.x.y:9111/metrics`.

First, add new Prometheus target: `backup.x.y:9111`. Ensure that the target is alive and Prometheus
can gather metrics.

Then, find your own backup metrics -- run these Prometheus queries:

    backups_total{user="<your-github-username>"}
    backup_last_success_time{user="<your-github-username>"}

Finally, create a new Grafana dashboard named "Backups" that visuzlizes the following info:
 - How many full MySQL backups were created
 - How many incremental MySQL backups were created (if you are doing incremental backups)
 - When was the last MySQL backup created

And all the same info for InfluxDB.

Hints:
 - You can display all backup type counts on the same chart (try "Stat"); use `{{service}}` and
   `{{type}}` labels in legend to identify them
 - `backup_last_success_time` is UNIX time (number of seconds since Jan 1, 1970); use this query to
   find how many seconds ago was the latest backup created:
   `time() - backup_last_success_time{user="<your-github-username>"}`
  - Use `seconds (s)` unit in Grafana chart to convert seconds to human readable time period


## Expected result

Your repository contains these files and directories:

    backup_restore.md
    backup_sla.md  # (updated as needed)
    group_vars/all.yaml
    infra.yaml
    roles/
        grafana/files/backups.json
        influxdb/tasks/main.yaml
        init/tasks/main.yaml
        mysql/tasks/main.yaml

Your repository also contains all the required files from the previous labs.

Every service you've deployed so far can be restored by following the instructions in the
`backup_restore.md`.
