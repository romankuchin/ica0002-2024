# Lab 8

In this lab we will setup centralized logging.

## Task 1: Install InfluxDB

Follow the official guide: https://docs.influxdata.com/influxdb/v1/introduction/install/#installing-influxdb-oss

## Task 2: Create agama-client service on one of VMs

Find bash script "agama-client" in 08-files.

Place this script to file /usr/local/bin/agama-client.

Create a service "agama-client" that runs from user "agama-client". Check 08-files for systemd service unit example. Place it into /etc/systemd/system/.

Don't forget to execute on systemd config change:

    systemctl daemon-reload

Docs: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_module.html.

agama-client script requires config file:

    /etc/agama-client/agama-client.conf

Example can be found in 08-files as well.

## Task 3: Add Agama monitoring to main Grafana dashboard

Add new Grafana datasource: influxdb:\<agama_client_db_name\>. It should be provisoned automaticaly via Grafana provisioning.

Use this datasource for new panels in main dashboard from previous lab.

New panels should show:

- graph with item counts for all discovered Agamas
- current number of items in your Agama

No ip addresses are allowed.

Don't forget to update json in your Ansible repo!

## Task 4: Setup Telegraf

Install Telegraf on the same VM where InfluxDB is located. Docs: https://docs.influxdata.com/telegraf/v1/install/#install-from-the-influxdata-repository

Installation steps can be done in "influxdb" role.

Configure Telegraph for only syslog input and only influxdb output. Hint:

    telegraf config --help

Use UDP as a transport.

## Task 5: Setup rsyslog

Configure rsyslog on all VMs to send all logs to Telegraf. Docs: https://github.com/influxdata/telegraf/blob/master/plugins/inputs/syslog/README.md

Configure rsyslog in `init` role.

Use UDP as a transport.

## Task 6: Create logging dashboard in Grafana

Add one more datasource: influxdb:telegraf

Import Grafana dashboard for Syslog: https://grafana.com/grafana/dashboards/12433-syslog/

Do not forget to add new datasource and dashboard to Grafana provisioning.

## Task 7: Add InfluxDB monitoring

Install InfluxDB stats exporter: https://github.com/carlpett/influxdb_stats_exporter

Download binary from latest [release](https://github.com/carlpett/influxdb_stats_exporter/releases/tag/v0.1.1) to /usr/local/bin/.

Create new systemd service. Run it with user `prometheus` as all other exporter do. Describe the service in /etc/systemd/system/prometheus-influxdb-stats-exporter.service.

Add couple more panels to your `Main` Grafana dashboard:

- InfluxDB health (influxdb_exporter_stats_query_success)
- InfluxDB write rate (influxdb_write_write_ok)

Don't forget to update json in your Ansible repo!

## Task 8: Supress InfluxDB requests logging

By default InfluxDB logs every request, which floods the logs.

Add to \[http\] section of influxdb config:

    log-enabled = false
    write-tracing = false

Add to \[data\] section of influxdb config:

    query-log-enabled = false

## Task 9: Recheck task 2 from previous lab

Wording was changed slightly.

## Expected result

Your repository contains these files and directories:

    ansible.cfg
    group_vars/all.yaml
    hosts
    infra.yaml
    roles/influxdb/tasks/main.yaml
    roles/agama_client/tasks/main.yaml

Your repository also contains all the required files from the previous labs.

Your repository **does not contain** Ansible Vault master password.

Everything is installed and configured with this command:

	ansible-playbook infra.yaml

Running the same command again does not make any changes to any of the managed
hosts.

After playbook execution you should be able to see all logs in one Grafana dashboard.
