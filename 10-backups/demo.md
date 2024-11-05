# Week 10 demo: backup tools

## Intro

There are a lot of ways how to manage SQL backups. This demo will show only a few of them, not
necessarily the best ones -- but should give you some basic understanding of how backups work.

First, we will set up a primitive backup system using `mysqldump` and `scp`.

Then we will improve it using more advanced tools: `rsync` and `duplicity`.

Finally, we will automate our backups with Crontab.

All commands shown below should be run as user `backup` in its home directory `/home/backup` unless
explicitly stated otherwise.

This demo is by no means an example of a complete backup system. Its goal is to illustrate only
_some_ of the aspects of a backup process.


## Setup

For this demo we will need to set up a few things first:
 1. App server with Agama stack
 2. MySQL server with Agama database from [lab 4](../04-troubeshooting)
 3. Working connection to backup server as described in [lab 9](../09-backups) -- user `backup` on
    the MySQL server can connect to backup server over SSH
 4. User `backup` access to MySQL database; it will be configred in the following lab task 1

![](./backups-demo-agama.png)


### Block Agama clients

You may want to restrict access to your Agama from other hosts so that other student's Agama
clients would not change your data. This can be achieved by adding this block to the `server{}`
block in your Nginx site configuration:

        allow 192.168.42.122;  # public access to 192.168.42.x hosts
        allow 192.168.43.20;   # public access to 192.168.43.x hosts
    {% for i in hostvars | sort %}
        allow {{ hostvars[i]['ansible_default_ipv4']['address'] }};  # my own VM
    {% endfor %}
        deny all;

In this demo MySQL database named `agama` is used (yours may be named differently) with a single
table named `item` (it is created by Agama app automatically).

Also in this demo backup server hostname is `backup.foo.bar`. Yours will be different, should be
`backup.<your-domain>` as required in lab 9.

Note: make sure to complete task 2 of the lab 10 before running any further command from this demo.


## Extract data from the existing database

On a MySQL server we should have MySQL server running and database called `agama` created with a
single table called `item`. You can check the table contents by running this command as user
`backup`:

    mysql -e 'SELECT * FROM agama.item'

You should see something like this:

    +----+---------+-------+
    | id | value   | state |
    +----+---------+-------+
    |  3 | Frodo   |     1 |
    |  4 | Samwise |     1 |
    |  5 | Merry   |     1 |
    |  6 | Pippin  |     1 |
    +----+---------+-------+

This is the initial state of our database.

You can extract (called 'dump' in database world) the data from running MySQL database with this
command:

    mysqldump agama

This is the data we will need to backup, and this data should be sufficient to restore the database.

Save the MySQL dump to a file:

    mysqldump agama > agama.sql
    less agama.sql

That's it. We now have a dump of the latest state of MySQL database `agama`, and a simple script to
create another dump when needed.

We will now need to upload the backup to the backup server.


## SCP

SCP, or [Secure copy protocol](https://en.wikipedia.org/wiki/Secure_copy_protocol) is the simplest
way to transfer files between two different machines.

You can upload the MySQL dump to backup server with one simple command (note the `:` separating the
server address and the file name):

    scp agama.sql <user>@backup.foo.bar:agama.sql

First argument (`agama.sql`) is the name of the source files to copy, and the second one
(`backup.foo.bar:agama.sql`) is address of the remote machine and the destination file location.
It can be omitted if the file names are the same:

    scp agama.sql <user>@backup.foo.bar:

This will upload the previously created `agama.sql` file to the backup server over SSH. The dump
file copy should now appear **on the backup server**:

    less ~/agama.sql

So the '-2-' part of the backup rule '3-2-1' is implemented: you have two copies of the data stored
locally (on site).

However `scp` might be not the best choice for larger amounts of data.

For the single SQL table with just a few lines it may be enough, but for real data cases with lots
of larger files `scp` has a lot of limitations. For instance, it will upload the entire file every
time. Try running the same upload command again, multiple times:

    scp agama.sql <user>@backup.foo.bar:
    scp agama.sql <user>@backup.foo.bar:
    scp agama.sql <user>@backup.foo.bar:

Note that the number of bytes uploaded (column 3) is the same every time, and is equal to the actual
size of the file:

    ls -la agama.sql

What if we could just upload the difference between files to save the time and network bandwidth?
This approach is called 'synchronization', or 'sync' for short, and there is a tool for that.


## Rsync

[Rsync](https://rsync.samba.org) is a protocol and simple utility for synchronizing files between
different directories on one computer, and also different computers over the network. We will use it
to upload our MySQL dump file to the backup server as we previously did with `scp`:

    rsync -v agama.sql <user>@backup.foo.bar:

Same logic here: first argument is the list of files to copy, and the second one is the destination
directory.

Note that amount of bytes transferred is much less than the file size:

    ...
    sent 95 bytes  received 53 bytes  98.67 bytes/sec
    total size is 2,021  speedup is 13.66


This is happening because `rsync` is not uploading the entire file but only the differences; in this
case the file is the same in source (MySQL server) and destination (backup server), so no actual
data chunks are sent at all; only a few bytes (99 sent, 53 received in this example) are spent on
figuring out the difference.

Let's now add some data to the database by add a few more items via Agama web UI. Once done, check
the contents of the database again:

    mysql -e 'SELECT * FROM agama.item'

    +----+---------+-------+
    | id | value   | state |
    +----+---------+-------+
    |  3 | Frodo   |     1 |
    |  4 | Samwise |     1 |
    |  5 | Merry   |     1 |
    |  6 | Pippin  |     1 |
    |  7 | Aragorn |     0 |  <-- added
    +----+---------+-------+

Run the backup script again to extract the latest data:

    mysqldump agama > agama.sql

And run the `rsync` again to sync the dump to backup server:

    rsync -v agama.sql <user>@backup.foo.bar:

This command should print something similar to:

    ...
    sent 1,428 bytes  received 53 bytes  987.33 bytes/sec
    total size is 2,037  speedup is 1.38

The amount of bytes transferred is now bigger, obviously some changes were sent. But the sent
changes together with `rsync` own protocol payload (1428 bytes) are still smaller than the actual
file size (2037 bytes here).

The win in this example may seem insignificant, but imagine that you have 100 GB database dumps, and
only small part of the actual data is changing between dumps. You will clearly win a lot of network
bandwidth while using `rsync` instead of `scp`.

So now we have at least two options how to upload the backups to the backup server. But are these
backups usable? Let's try to restore them to find out.

For things to look more real let's actually destroy the table first, and also delete all local
backups to make things more interesting:

    mysql -e 'DROP TABLE agama.item'
    rm agama.sql

Database is gone now, all data is lost:

    mysql -e 'SELECT * FROM agama.item'
    ERROR 1146 (42S02) at line 1: Table 'agama.item' doesn't exist

If you refresh the Agama app page it will re-create the database with default items, but all
precious customer data is gone :(

But we have backups! We now need to download the backup to restore the database. With `rsync` it
would just mean syncing the files in the 'other direction', from backup server to database server:

    mkdir restore
    rsync -v <user>@backup.foo.bar:agama.sql restore/

Note that the first argument is the source file _on the remote machine_ in this case, and the second
one is the destination directory on the server that is being restored.

Also note that restore location is different from the backup location. It is always a good idea to
keep the backup and restore data separately in order not to destroy the latest backup accidentally.
Remember, it is better to have more copies of the backup than have no copies at all.

Check the downloaded backup:

    less restore/agama.sql

It should be the same SQL file as we previously uploaded to the backup server. Now let's try to
restore the database:

    mysql agama < restore/agama.sql

**Note:** this will destroy the current content of `agama` database, if any, and replace it with the
data from the backup!

Check the content of the `agama` table now; it should be the same as prior to the last backup:

    mysql -e 'SELECT * FROM agama.item'

And the Agama web UI should show the correct list now.

So the backup is usable -- it can be used to restore the service.

There is one significant problem with using `rsync` as a backup tool though. It cannot store
multiple versions of the files being synchronized. To be precise, `rsync` can either store one or
two versions of the files, but not more.

Let's add another record to the database:

    +----+---------+-------+
    | id | value   | state |
    +----+---------+-------+
    |  3 | Frodo   |     1 |
    |  4 | Samwise |     1 |
    |  5 | Merry   |     1 |
    |  6 | Pippin  |     1 |
    |  7 | Aragorn |     0 |
    |  8 | Boromir |     0 |  <-- added
    +----+---------+-------+

... and create another backup:

    rm -rf restore
    mysqldump agama > agama.sql
    rsync -bv agama.sql <user>@backup.foo.bar:

Note the `-b` parameter -- this tells `rsync` to create a backup copy of the file being synced if
this file was changed. Check file differences **on the backup server**:

    ls -la agama.sql*
    diff -u --color agama.sql~ agama.sql

If you create another version of the backup, the oldest version will be deleted, and only the last
two versions will be preserved. Add another record and create another backup:

    +----+---------+-------+
    | id | value   | state |
    +----+---------+-------+
    |  3 | Frodo   |     1 |
    |  4 | Samwise |     1 |
    |  5 | Merry   |     1 |
    |  6 | Pippin  |     1 |
    |  7 | Aragorn |     0 |
    |  8 | Boromir |     0 |
    |  9 | Gandalf |     0 |  <-- added
    +----+---------+-------+

    mysqldump agama > agama.sql
    rsync -bv agama.sql <user>@backup.foo.bar:

Check the backup directory content on the backup server:

    ls -la agama.sql*
    diff -u --color agama.sql~ agama.sql

So `rsync` alone does not quite solve the problem if you need more than two versions of the backup
to be stored :(

There are few other things that are essential for backups but cannot be handled with `rsync` alone:
 - You need data compression to optimize both the storage and bandwidth? Write another script.
 - You need to encrypt your backups? Write another script.
 - You need some mechanism to rotate backup versions and delete the old ones? Write another script.
 - And so on.

One important thing to keep in mind about `rsync` that it is not a backup tool -- it is
_data synchronization_ tool. This is a good choice to implement the '-1-' part of the '3-2-1' backup
rule: once you have a repository of usable backups on your backup server you can use `rsync` to
synchronize this repository to some remote (off-site) location.

But how to build this backup repository in the right way, with multiple version of the backup
stored? Surely there is a tool for that, too.


## Duplicity

[Duplicity](https://duplicity.gitlab.io) is a specialized backup tool that operates over Rsync
protocol to transfer the data and adds some backup specific features to that. It is not installed on
Ubuntu servers by default, you may need to install it first:

    ansible.builtin.apt:
      name: duplicity

Duplicity supports incremental backups, backup versioning, rotation and encryption out of the box.
We will skip the encryption part for this demo, but again, this is only done
_for demonstration purposes_.

**Always encrypt your production backups, and make sure to backup the encryption keys separately!**

Let's create another backup with Duplicity. We have a recent MySQL dump already, we can reuse it:

    duplicity --no-encryption full agama.sql rsync://<user>@backup.foo.bar//home/<user>

Note that we're creating a _full_ backup here. First backup should always be a full one. Second,
third and later could be incremental, but the full backup should be created again from time to time.

Also note that Duplicity is a bit more picky about remote locations; you cannot omit the directory
path as you could with Rsync or SCP. If you do, Duplicity will try to write to the root of the file
system. Your directory on the backup server is `/home/<your-github-username>`; you have to either
provide it explicitly if using Duplicity, or use `.` as an alias. So this command would also work:

    duplicity --no-encryption full agama.sql rsync://<user>@backup.foo.bar/.

Check the files created by Duplicity **on the backup server**:

    ls -la duplicity*

Note that three additional files were created:

    duplicity-full-signatures.20211031T181141Z.sigtar.gz
    duplicity-full.20211031T181141Z.manifest
    duplicity-full.20211031T181141Z.vol1.difftar.gz

This solution seems more complicated than a regular `rsync`. So what's the win? Let's add some more
data to our database and create another backup, _incremental_ one this time, to find out:

    +----+---------+-------+
    | id | value   | state |
    +----+---------+-------+
    |  3 | Frodo   |     1 |
    |  4 | Samwise |     1 |
    |  5 | Merry   |     1 |
    |  6 | Pippin  |     1 |
    |  7 | Aragorn |     0 |
    |  8 | Boromir |     0 |
    |  9 | Gandalf |     0 |
    | 10 | Gimli   |     0 |  <-- added
    +----+---------+-------+

    mysqldump agama > agama.sql
    duplicity --no-encryption incremental agama.sql rsync://<user>@backup.foo.bar/.

Note the `incremental` parameter. On the backup server three more files are created:

    duplicity-inc.20211031T181141Z.to.20211031T181808Z.manifest
    duplicity-inc.20211031T181141Z.to.20211031T181808Z.vol1.difftar.gz
    duplicity-new-signatures.20211031T181141Z.to.20211031T181808Z.sigtar.gz

Let's now inspect what Duplicity is writing to these files (these commands should be run
**on the backup server**; your file names will differ):

    zless duplicity-full.20211031T181141Z.vol1.difftar.gz
    zless duplicity-inc.20211031T181141Z.to.20211031T181808Z.vol1.difftar.gz

Note that incremental backup contains only the part of SQL dump. Is it broken? Surely not. Duplicity
can use this increment, all previous increments and the full backup to restore your original SQL
dump file.

Also note that incremental file contains much more info than just a diff. This is happening because
Duplicity uses other mechanism to compute the file differences: `diff` operates on text files while
Duplicity computes binary data blocks of certain length.

So, main question -- is this backup usable? Restoring it is the way to find out!
Destroy the database first:

    mysql -e 'DROP TABLE agama.item'
    rm agama.sql
    rm restore/*

... and restore the backup:

    duplicity --no-encryption restore rsync://<user>@backup.foo.bar/. restore/agama.sql
    mysql agama < restore/agama.sql
    mysql -e 'SELECT * FROM agama.item'

Ta-daa!

Duplicity downloaded needed full backup and increments from the backup server and assembled the
original SQL dump file from these. Note that the file itself is the same as we backed up:

    less restore/agama.sql

And there are other Duplicity perks as well:
 - Backup encryption using GnuPG is enabled by default; we were disabling it in this demo with
   `--no-encryption` parameter, but in real life you shouldn't;
 - Backup data is compressed to optimize both the storage and network bandwidth; `rsync` tool would
   only care about the latter;
 - There are options to delete old backups -- these can be used in backup scripts to keep the backup
   repository fit;
 - Cloud storage support: you can upload backups directly to AWS S3 and others -- you may not even
   need a backup server, but only as long as you still keep following the '3-2-1' rule!

So seems that we have a good enough solution to create the backups manually. But good backup is run
automatically by established schedule. So how to automate it?

Of course, there is a tool for that :)


## Cron

Cron is a time based job scheduler for UNIX systems. It is very widely used, and your managed system
will have it installed by default in most cases.

Cron schedules (called 'crontabs') are stored in `/etc/cron.d` directory:

    ls -la /etc/cron.d/*

...and have the following structure:

    <schedule> <user> <shell-command>

`<user>` part is a later addition to some modern Cron implementations; originally Cron jobs could
only be run as `root`.

Cron schedule consists of five fields:

    <minute> <hour> <day-of-month> <month> <day-of-week>

whereas '*' means 'every'. For example, every-minute schedule definition is:

    * * * * *

Daily schedule (01:42 AM) would be defined as

    42 1 * * *

Weekly schedule (02:37 AM every Sunday) would be defined as

    37 2 * * 0

and so on.

You can also define more complex schedules with special characters;
[Wikipedia article on Cron](https://en.wikipedia.org/wiki/Cron#CRON_expression) is a good starting
point.

**Question:** For these Cron schedules, when would the job be run?

    1 2 3 * *

    1 2 3 4 5

    * * 3 4 *

There is a nice online tool to find out: https://crontab.guru.

Crontab is the simplest way to automate you backups: you will just need to write a script to create
a backup, and define a schedule when to run it.

Based on on current setup one possible backup crontab (stored in `/etc/cron.d/mysql-backup` for
example) could look like this:

    11 0 * * *    backup  mysqldump agama > agama.sql
    12 0 * * 0    backup  duplicity full agama.sql rsync://<user>@backup.foo.bar/mysql
    12 0 * * 1-6  backup  duplicity incremental agama.sql rsync://<user>@backup.foo.bar/mysql

This would
 - create a fresh MySQL dump nightly at 00:11 AM,
 - create a full backup every Sunday at 00:12 AM, and
 - create an incremental backup every other day (Monday to Saturday) at 00:12 AM

`mysql` directory in your home directory is pre-created for you on the backup server.

How to verify if your crontab is correct? Wait for 1..2 minutes and check the system logs:

    tail /var/log/syslog

-- if you made a typo in the crontab you will find something similar there:

    Oct 31 18:29:01 red cron[705]: (*system*backup) RELOAD (/etc/cron.d/backup)
    Oct 31 18:29:01 red cron[705]: Error: bad minute; while reading /etc/cron.d/backup
    Oct 31 18:29:01 red cron[705]: (*system*backup) ERROR (Syntax error, this crontab file will be ignored)

We can add another rule to clean up the backup repository and discard old backups:

    9 0 * * 0    backup  duplicity remove-older-than 30D rsync://<user>@backup.foo.bar//home/<user>

This would delete all backups older than 30 days.

Finally, we can add another rule to the _backup server_ crontab to sync the backup repository to
offsite location periodically:

    30 1 * * *  backup  rsync -v /home/user/duplicity* some-offiste-backup-server:/srv/backup

**Question:** What is RPO (recovery point objective) of this backup system?
For simplicity let's agree that
 - every data transfer session between servers takes 1 minute, i. e. backup is successfully written
   to remote server exactly 1 minute after the command was started on local server, and
 - server clocks are in perfect sync


## Summary

This demo illustrates the usage of a few basic tools (`mysqldump`, `scp`, `rsync`, `duplicity` and
`cron`) in the context of a backup system.

The result is rather a proof of concept for simple services with small amount of data, but it is
certainly not a complete backup system. We are still missing:
 - monitoring -- how can we make sure that backup was created in time and successfully?
 - verification -- we know how to verify the backup manually, but ideally it should be automated as
   well
 - proper security measures
 - documentation and so on

Once your system grows out of home-made crontabs and Duplicity scripts there are lots of tools on
the market that you could consider:
 - [BorgBackup](https://www.borgbackup.org) -- simpler one,
 - [Bacula](https://www.bacula.org) and [Bareos](https://www.bareos.com) -- more sophisticated ones,
 - a few proprietary solutions

But none of them will probably work for you as is, out of the box. You will still need to configure
them to do exactly what you need, and for that you will need a practical knowledge how backup
process works internally.

In simpler words, don't even attempt on complex systems until you know how to set up a backup system
with Cron and Duplicity :)
