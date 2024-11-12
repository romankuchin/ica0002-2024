# Lab 11

In this lab we will set up MySQL in highly available mode, namely configure a replication with two
MySQL servers.

A lot of things can go wrong with MySQL in this lab. If you feel that you are stuck and MySQL is
broken beyond repairs -- delete it and start from scratch:

    systemctl stop mysql
    apt-get purge mysql-*
    rm -rf /etc/mysql /var/lib/mysql

Answer 'yes' is asked about deleting all the databases. We have backups set up, right? :)

Also in this lab we'll try different approach to service provisioning -- first, we'll set up desired
monitoring, and then update the services and watch them appear in Grafana.


## Task 1

Set up the infrastructure you've built before:

    ansible-playbook infra.yaml

Add another dashboard named 'MySQL' to Grafana.

Copy all MySQL graphs there from Main dashboard (MySQL status, query statistics); see
[lab 7](../07-grafana) for details.

Add a few more graphs for every MySQL server (we have one server so far but will have more soon):
 - widget(s) showing MySQL server ids (Prometheus metric `mysql_global_variables_server_id`)
 - graph(s) showing historical data for MySQL server read only status (Prometheus metric
   `mysql_global_variables_read_only`)
 - graph(s) showing historical data for MySQL replication threads (Prometheus metrics
   `mysql_slave_status_slave_io_running` and `mysql_slave_status_slave_sql_running`)

On the first run you should see these values in Grafana:
 - `mysql_global_variables_server_id` should be 1
 - `mysql_global_variables_read_only` should be 0
 - `mysql_slave_status_slave_io_running` and `mysql_slave_status_slave_sql_running` should show no
   data

These values will change as your progress with tasks 3..5.

Save your updated Grafana dashboard as `roles/grafana/files/mysql.json` (same as other dashboards in
labs 7 and 8).

More info about MySQL replication threads (IO and SQL) can be found here:
https://dev.mysql.com/doc/refman/8.0/en/replication-threads.html.

Keep the Grafana dashboard open for the remaining part of the lab, and make sure to set the
auto-refresh to observe the changes in close-to-real time.


## Task 2

Modify your `mysql` role from previous labs and add another MySQL user named `replication`.

This user should use a password to log in and should be able to access this MySQL server from any
host in our network -- similar configuration as `agama` user.

This user, however, should have different permissions: `REPLICATION SLAVE` on every database and
table (`*.*`). Check Ansible module `mysql_user`
[documentation](https://docs.ansible.com/ansible/latest/collections/community/mysql/mysql_user_module.html)
for details on how to achieve this.

Run Ansible playbook to apply the changes.

Run this command on the managed host to verify that the user can log in:

    mysql -u replication -p

You should get into MySQL shell. Press `Ctrl+D` or type `exit` to exit the MySQL shell.


## Task 3

Update your Ansible inventory file and add another host to the `db_servers` group. This group should
contain two hosts now.

Update the MySQL configuration file (`override.cnf` discussed in detail in
[lab 4](../04-troubleshooting)) and add the following parameters to the `mysqld` section:

    log-bin = /var/log/mysql/mysql-bin.log
    relay-log = /var/log/mysql/mysql-relay.log
    replicate-do-db = {{ mysql_database }}
    server-id = {{ node_id }}

`replicate-do-db` only limits the replication to one database -- our application database. This is
needed to skip replication of MySQL own database named `mysql` that contains user and permission
info -- these are managed by Ansible on every MySQL server in our case, and it will interfere with
MySQL own replication mechanisms.

`node_id` should be set in `group_vars/all.yaml`, and should be different for each of your VMs.
One way to calculate node id is:

    node_id: "{{ (ansible_port / 100) | int }}"

You can use other methods if you want -- main goal is to get unique node id for every managed host.

Run the playbook again. It should install and configure the MySQL server on both machines.

Your Grafana dashboard for MySQL should show that
 - both MySQL servers are up
 - ids of both MySQL servers are different

If the new server is not added to Grafana automatically:
 - Make sure that MySQL is running on that server
 - Make sure that MySQL Prometheus exporter is running
 - Make sure that the new node is added to Prometheus targets for `mysql` job


## Task 4

We'll need to set one of the MySQL servers (one that will become replica later) to read only mode.
Previously we've set MySQL parameters in the configuration file, and applying those required MySQL
server to be restarted. Some of the parameters, however, can (and should) be applied _dynamically_,
without the server restart. Setting read only mode dynamically will allow us to swap the source and
replica server without restarting the MySQL server process.

There is Ansible module
[mysql_variables](https://docs.ansible.com/ansible/latest/collections/community/mysql/mysql_variables_module.html)
that handles dynamic MySQL parameters. Update the `mysql` role and add a task that will set the read
only mode for replica server, and remove it from source server; example:

    community.mysql.mysql_variables:
      variable: read_only
      value: "{{ 'OFF' if inventory_hostname == mysql_host else 'ON' }}"
      mode: persist

 - corresponding MySQL variable name is `read_only`
 - value `ON` or `OFF` is selected based on the host role here; if the host name in Ansible
   (`inventory_hostname`) matches the `mysql_host` value (this is the host Agama connects to;
   covered in labs 4 and 5) then `read_only` is set to `OFF` and writes are allowed, otherwise `ON`
   -- only reads are allowed on this MySQL instance
 - `mode: persist` is needed to preserve the read only mode after MySQL restart

**Important!** `read_only` values `ON` and `OFF` MUST be written in Ansible exactly as this; `yes`,
`false`, `1` and other values will probably work, but Ansible will generate a change on every run.

Feel free to update the Ansible task to suite your needs.

Once done, run Ansible to apply the changes. In Grafana you should see that one of the MySQL servers
has now switched to read only mode.

MySQL should **not** be restarted if read only mode is changed!


## Task 5

Next, we will need to configure the MySQL replication --
[mysql_replication](https://docs.ansible.com/ansible/latest/collections/community/mysql/mysql_replication_module.html)
module will be very useful to automate it.

Note that setting up replication in our setup is **destructive** action:
 - you should only configure a new replication with empty database, after the `agama` database is
   created but before the Agama app is deployed
 - running Ansible again without any code changes should not set up the replication again

First, create two handlers in the `mysql` role:

    - name: Reset MySQL source
      community.mysql.mysql_replication:
        mode: "{{ item }}"
        login_unix_socket: /var/run/mysqld/mysqld.sock
      loop:
        - stopreplica
        - resetprimary
      when: inventory_hostname == mysql_host

    - name: Reset MySQL replica
      ...

`Reset MySQL source` will be run once for every element of the `loop` list:
 - once for `mode: stopreplica`
 - once more for `mode: resetprimary`

`Reset MySQL source` will only be run on MySQL source host:

      when: inventory_hostname == mysql_host

Use it as an example, and write another handler for MySQL replica:
 - it should perform 4 actions as shown in the demo on lecture: `STOP REPLICA`,
   `CHANGE REPLICATION SOURCE` (named `changeprimary` in Ansible module), `RESET REPLICA`,
   `START REPLICA`, in this order
 - it should be run only on replica servers (not source)
 - check `mysql_replication` module docs for ideas, details and examples

Both handlers should be notified if at least one of these tasks generates a change:

 - task that creates `agama` database ([lab 4](../04-troubleshooting))
 - task that changes MySQL server read only mode (on or off, task 4)

Then, delete the `agama` database (if any) on **both** MySQL servers. Note that this is a one time
action that is only needed for this task. Later replication should be working without the need to
delete the database:

    mysql -e 'DROP DATABASE agama'

Once ready, run the Ansible to apply the changes. Check your Grafana dashboard for MySQL:
 - both MySQL servers should be up
 - exactly one MySQL server should accept writes (source); another should be read only (replica)
 - IO and SQL replication threads both should be running exactly on one MySQL server, and that
   server should be read only

Open the Agama page (it should work, obviously) and generate some changes: add or delete some
records, change record states. Ensure that the changes are propagated to both databases, source and
replica -- run this on corresponding MySQL server as user root to see the changes:

    mysql -e 'SELECT * FROM agama.item'

If replication is not happening, re-check the replication status -- run this on replica server as
user root (note the `-Ee` switch: `E` tells MySQL to format the output vertically):

    mysql -Ee 'SHOW REPLICA STATUS'

It should contain no errors in `Last_IO_Error` and `Last_SQL_Error` fields.

If the output of the last command contains something similar to

    Last_SQL_Error: Error executing row event: 'Table 'agama.item' doesn't exist'

-- it means that the MySQL replica cannot pick up some entries from the replication log on source
server (creating the database), and fails to proceed with the next steps (adding rows). This may
happen if you have created and populated the database _before_ setting up the replication. If you
are getting this error -- please re-do this task from the `DROP DATABASE` step -- you probably
didn't wipe the database on source server properly.

Otherwise -- congratulations! You now know how to set up the simple MySQL replication with Ansible.


## Task 6

Implement and try the source/replica switchover with Ansible.

This should be really simple now, you have all the needed resources already.

Add some tag to both `Database servers` and `Web servers` plays in `infra.yaml`, so you can do the
switchover by running only these two plays, example command (don't run yet):

    ansible-playbook infra.yaml -t mx

Change the `mysql_host` value in the `group_vars/all.yaml` (from machine 1 to machine 2 or vice
versa), or the `db_servers` member ordering in the inventory file.

Run the Ansible with the tag you've just added.

As a result,

 - MySQL source server should be changed
 - MySQL replication should be reconfigured on another MySQL server
 - MySQL processes should not be restarted
 - uWSGI Agama configuration should be changed to connect to another database server
 - uWSGI should be restarted so that Agama could pick up the change

Check the Grafana dashboard. Verify that MySQL source and replica are changed, there is still one
source and one replica, which is read only.

Ensure that Agama still works, and any changes you make are visible in both databases.


## Task 7

There is one more problem to solve. Now when we have two MySQL servers, backups are also run on
both, which is not right:
 - database content on all servers should be the same, so no need to backup it twice
 - running `mysqldump` from both source and replica at the same time may end with two unusable dumps

Note that just deploying the Cron tab to only one server is not enough. If the source and replica
are swapped, not only the Cron tab needs to be deployed to the new server but also deleted from the
old one.

Easiest way to do it is to add the Cron tab file on every server, but only add the jobs on replica.
Update the Cron tab template in the `mysql` role created in [lab 10](../10-backups) to something
like this:

    {% if inventory_hostname == mysql_backup_host %}
    x x x x x  backup  <command>
    ...
    {% endif %}

`mysql_backup_host` is the new variable that needs to be added to `group_vars/all.yaml`:

    mysql_backup_host: "{{ groups['db_servers'] | reject('eq', mysql_host) | first | default(mysql_host) }}"

Logic of selecting the host to run MySQL backups on is following:
 - for all hosts in `db_servers` group (`groups['db_servers']`)...
 - skip `mysql_host` which is MySQL source host (`| reject('eq', mysql_host)`)...
 - from remaining hosts (replicas) select the first one (`| first`).
 - if that didn't work, run backups on `mysql_host` a. k. a. source host (`| default(mysql_host)`)

This will work correctly with 1, 2 or more hosts in `db_servers` group:
 - if the group contains only one host -- backup will be done on that
 - if the group contains 2 or more hosts -- backup will be done on the first found replica host

Run the Ansible again to apply changes. Make sure that Cron jobs are deleted from the MySQL source
server (Cron tab is empty).

Then, swap the source and replica servers as you did in the task 6. Make sure that Cron jobs is
added to the new replica, and deleted from the new source server.

Finally, ensure that new backup was created successfully on replica host -- as you did in lab 10.


## Expected result

Your repository contains these files and directories:

    ansible.cfg
    hosts
    roles/
        grafana/files/mysql.json
        mysql/tasks/main.yaml

You can change MySQL source and replica with changing only `mysql_host` variable value, and running
Ansible afterwards.

You can verify if MySQL replication is working by running needed shell commands on MySQL replica
server.

You can verify if MySQL replication is set up correctly by checking the Grafana dashboard for MySQL.
